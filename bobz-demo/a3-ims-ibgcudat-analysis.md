# IMS Database Analysis: IBGCUDAT — Segments, PSB, and CUSTOMER/CUSTACCS Relationship

**Date:** 2026-07-28  
**Mode:** Z Architect  
**Files read:**  
- `src/base/ims/cobol/IBGCUDAT.cbl` — program source  
- `src/base/ims/PSB/IBGCUDAT.asm` — Program Specification Block  
- `src/base/ims/DBD/CUSTOMER.asm` — CUSTOMER Database Descriptor  
- `src/base/ims/DBD/CUSTACCS.asm` — CUSTACCS Database Descriptor  
- All other DBDs and PSBs in `src/base/ims/DBD/` and `src/base/ims/PSB/` for full-ecosystem context

---

## Setup

> ⚠️ **No single file needs to be open for this prompt** — Bob uses the **Z Architect** mode's workspace scan.  
> However, for best results open the IMS source folder so Bob can read PSB and DBD assembly source directly:  
> `src/base/ims/`
>
> The prompt requires reading **both the PSB** (which segments the program is authorised to access) **and the DBDs** (which define what those segments actually contain). Neither source alone is sufficient.

Switch to **Z Architect** mode.

---

## Prompt

> Show me all the IMS segments that IBGCUDAT accesses, and explain the parent-child relationship between CUSTOMER and CUSTACCS databases.

---

## Output

### Part 1 — Segments IBGCUDAT Accesses

#### PSB: `IBGCUDAT.asm`

```assembler
PCB    TYPE=DB,DBDNAME=CUSTOMER,PROCOPT=G,KEYLEN=4,
       PCBNAME=CUSTOMER
SENSEG NAME=CUSTOMER,PARENT=0
PSBGEN PSBNAME=IBGCUDAT,LANG=COBOL
```

IBGCUDAT has **one PCB** granting access to **one database** and **one segment**:

| Attribute | Value | Meaning |
|---|---|---|
| `DBDNAME` | `CUSTOMER` | The physical IMS database this PCB connects to |
| `PROCOPT` | `G` | **Get only** — read access, no insert/update/delete permitted |
| `KEYLEN` | `4` | Key feedback area length = 4 bytes (matches `CUSTID` field: `DATATYPE=INT`) |
| `SENSEG` | `CUSTOMER`, `PARENT=0` | Sensitive to the `CUSTOMER` segment at the root level (no parent) |

**IBGCUDAT accesses exactly one segment: `CUSTOMER` in the `CUSTOMER` database — read-only.**

---

#### Segment accessed: `CUSTOMER` (from `CUSTOMER.asm` DBD)

The CUSTOMER database is an **HDAM** (Hierarchical Direct Access Method) database stored on OSAM, keyed on `CUSTID`. It contains a single flat segment — no children.

| Field name | External name | Start byte | Length | Data type | Notes |
|---|---|---|---|---|---|
| `CUSTID` | `CUSTID` | 1 | 4 | INT | **Sequence field, unique** — the HDAM root key |
| `LASTNAME` | `LASTNAME` | 5 | 50 | CHAR | |
| `FIRSTNM` | `FIRSTNAME` | 55 | 50 | CHAR | External name differs from internal |
| `ADDRESS` | `ADDRESS` | 105 | 80 | CHAR | |
| `CITY` | `CITY` | 185 | 25 | CHAR | |
| `STATE` | `STATE` | 210 | 2 | CHAR | |
| `ZIPCODE` | `ZIPCODE` | 212 | 15 | CHAR | |
| `PHONE` | `PHONE` | 227 | 12 | CHAR | |
| `STATUS` | `STATUS` | 239 | 1 | CHAR | |
| `PASSWORD` | `PASSWORD` | 240 | 16 | CHAR | |
| `CUSTTYPE` | `CUSTOMERTYPE` | 256 | 1 | CHAR | External name differs from internal |
| `LASTLOGI` | `LASTLOGIN` | 257 | 23 | TIMESTAMP | `yyyy-MM-dd HH:mm:ss.SSS` format |

**Total segment size: 279 bytes**

---

#### What IBGCUDAT actually does with the segment

The program issues a **`GU` (Get Unique)** call with a qualified SSA:

```cobol
CALL 'CBLTDLI'
  USING GU, DBPCB, CUSTOMER-SEG, CUSTOMER-SSA1.
```

The SSA (`CUSTOMER-SSA1`) translates to: `CUSTOMER(CUSTID EQ <value>)` — a direct lookup by customer ID. This is equivalent to a primary-key `SELECT` in SQL.

The working-storage area `CUSTOMER-SEG` (declared in the COBOL program) maps exactly to the DBD segment layout:

| COBOL field | DBD field | Bytes |
|---|---|---|
| `CUSTID-CD` | `CUSTID` | 4 |
| `LASTNAME-CD` | `LASTNAME` | 50 |
| `FIRSTNAME-CD` | `FIRSTNAME` | 50 |
| `ADDRESS-CD` | `ADDRESS` | 80 |
| `CITY-CD` | `CITY` | 25 |
| `STATE-CD` | `STATE` | 2 |
| `ZIPCODE-CD` | `ZIPCODE` | 15 |
| `PHONE-CD` | `PHONE` | 12 |
| `STATUS-CD` | `STATUS` | 1 |
| `PASSWORD-CD` | `PASSWORD` | 16 |
| `CUSTOMERTYPE-CD` | `CUSTOMERTYPE` | 1 |
| `LASTLOGIN-CD` | `LASTLOGIN` | 23 |

On success (`DBSTAT = SPACES`), the program moves `FIRSTNAME-CD`, `LASTNAME-CD`, `ADDRESS-CD`, `CITY-CD`, `STATE-CD`, `ZIPCODE-CD`, `PHONE-CD`, and `CUSTID-CD` into the output message area and sends it back via `ISRT` to the I/O PCB.

On `GE` or `GB` status codes, it returns `"CUSTOMER DOES NOT EXIST"`. On any other status, it returns the raw status code as an error message.

---

### Part 2 — CUSTOMER vs CUSTACCS: The Parent-Child Relationship

#### The architectural question

There is **no parent-child relationship between the CUSTOMER and CUSTACCS databases** in the IMS sense — they are **two separate, independent HDAM databases**, each with a single flat root segment and `PARENT=0`. Neither is a logical child of the other.

The relationship between them is a **logical cross-reference** — CUSTACCS serves as an **account-to-customer join table**, implemented as its own physical database rather than as a child segment within CUSTOMER.

---

#### CUSTOMER database — `CUSTOMER.asm`

```
CUSTOMER (HDAM, OSAM)
└── Segment: CUSTOMER  [PARENT=0, root only]
        Key: CUSTID (INT, 4 bytes, unique sequence field)
        Size: 279 bytes
        Fields: CUSTID, LASTNAME, FIRSTNAME, ADDRESS, CITY,
                STATE, ZIPCODE, PHONE, STATUS, PASSWORD,
                CUSTOMERTYPE, LASTLOGIN
```

One segment, one hierarchy level, no children. A CUSTOMER record is a **self-contained customer profile** identified by a 4-byte integer `CUSTID`.

---

#### CUSTACCS database — `CUSTACCS.asm`

```
CUSTACCS (HDAM, OSAM)
└── Segment: CUSTACCS  [PARENT=0, root only]
        External name: CUSTOMERACCS
        Key: CUSACCID (BINARY, 12 bytes, multiple-valued — SEQ flag = M)
        Size: 16 bytes
        Fields:
          CUSTID   (INT,    4 bytes, start=1)   — customer reference
          ACCID    (LONG,   8 bytes, start=5)   — account reference
          ACCNUM   (INT,    4 bytes, start=13)  — account sequence number
```

> **Key difference from CUSTOMER:** `CUSTACCS` uses `SEQ=M` (multiple-valued sequence) vs `CUSTOMER`'s `SEQ=U` (unique). This means multiple `CUSTACCS` segments can exist with the same `CUSTID` prefix — one per account owned by that customer.

---

#### The logical relationship: CUSTACCS as a cross-reference table

CUSTACCS stores the **many-to-many mapping** between customers and accounts. Each CUSTACCS segment records one (customer → account) association:

```
CUSTACCS segment fields:
  CUSTID   = which customer  (4 bytes, INT)
  ACCID    = which account   (8 bytes, LONG, key into ACCOUNT database)
  ACCNUM   = account sequence number for this customer (1st, 2nd, 3rd…)
```

From the load data (`CUSTACCS.data`), the pattern is clear — rows are `(CUSACCID, CUSTID, ACCNUM)`:

```
101,1,1   → customer 1, account sequence 1  (ACCID=101)
102,1,2   → customer 1, account sequence 2  (ACCID=102)
201,2,1   → customer 2, account sequence 1
202,2,2   → customer 2, account sequence 2
...
```

Customer 2 has 5 accounts (201–205). Customer 8 has 5 accounts (801–805). This is a true one-to-many: one customer maps to N CUSTACCS records, each pointing to a different entry in the ACCOUNT database.

---

#### Why two separate databases instead of a child segment?

In IMS, an alternative design would be to make CUSTACCS a **child segment of CUSTOMER** within a single hierarchical database. The Bank of Z design chose separate HDAM databases instead. The implications:

| Design choice | Separate databases (actual) | Child segment (alternative) |
|---|---|---|
| **Access pattern** | Any program can open CUSTACCS independently without accessing CUSTOMER first | CUSTACCS would only be reachable by traversing CUSTOMER first |
| **PSB flexibility** | Programs like `IBACSUM` and `IBTRAN` can include a CUSTACCS PCB without a CUSTOMER PCB | Would require a combined PCB |
| **Lock granularity** | CUSTOMER and CUSTACCS can be locked independently | Locking CUSTOMER parent would cascade to CUSTACCS child |
| **Load/maintenance** | CUSTACCS can be bulk-loaded and reorganised independently | Reorganisation would affect the entire hierarchy |

The choice of separate HDAM databases reflects a **denormalised, performance-oriented** IMS design — common in high-volume OLTP banking systems where read paths need to be as direct as possible.

---

#### How a "find all accounts for customer X" query works across the two databases

No single program can join CUSTOMER and CUSTACCS in one IMS call. A program that needs both — like `IBACSUM` or `IBTRAN` — must:

1. Open a PCB to **CUSTOMER** → issue `GU CUSTOMER(CUSTID EQ x)` → get customer profile
2. Open a separate PCB to **CUSTACCS** → issue `GU CUSTACCS(CUSTID EQ x)` → get first account mapping
3. Loop with `GN CUSTACCS` (Get Next) → get subsequent account mappings for the same customer
4. For each ACCID found in step 2/3, open a third PCB to **ACCOUNT** → issue `GU ACCOUNT(ACCID EQ accid)` → get account details

This is the IMS equivalent of a SQL three-table join — but expressed as sequential DL/I calls across three physical databases.

---

### Part 3 — The Full IMS Database Ecosystem

For completeness, all 9 IMS databases in Bank of Z and how they relate:

| Database | Access method | Key field | Size | Role |
|---|---|---|---|---|
| `CUSTOMER` | HDAM/OSAM | `CUSTID` INT(4) unique | 279 bytes | Customer profile |
| `CUSTACCS` | HDAM/OSAM | `CUSACCID` BINARY(12) multiple | 16 bytes | Customer → Account cross-reference |
| `ACCOUNT` | HDAM/OSAM | `ACCID` LONG(8) unique | 25 bytes | Account record (balance, type, last transaction) |
| `HISTORY` | HDAM/OSAM | `TXID` LONG(8) unique | 56 bytes | Transaction history (amount, type, timestamp, account ref) |
| `TSTAT` | HDAM/OSAM | `TXID` LONG(8) unique | 59 bytes | Transaction status (start time, stop time, customer ref) |
| `CUSTTYPE` | HDAM/OSAM | `CODE` CHAR(1) unique | 21 bytes | Customer type reference (code + description) |
| `ACCTYPE` | HDAM/OSAM | `CODE` CHAR(1) unique | 21 bytes | Account type reference (code + description) |
| `TTYPE` | HDAM/OSAM | `CODE` CHAR(1) unique | 21 bytes | Transaction type reference (code + description) |
| `TSTATTYP` | HDAM/OSAM | `CODE` CHAR(1) unique | 21 bytes | Transaction status type reference (code + description) |

All nine are **single-segment HDAM databases** — flat, no child segments in any of them. The hierarchical relationships are implemented through cross-reference databases (`CUSTACCS`) and shared key fields (`ACCID` in HISTORY, `CUSTID` in TSTAT) rather than through IMS parent-child segments.

---

### Part 4 — PSB Cross-Reference: Which Programs Access Which Databases

| PSB (program) | CUSTOMER | CUSTACCS | ACCOUNT | HISTORY | TSTAT | ACCTYPE | CUSTTYPE | TTYPE | TSTATTYP |
|---|---|---|---|---|---|---|---|---|---|
| `IBGCUDAT` | G (get) | — | — | — | — | — | — | — | — |
| `IBSCUDAT` | R (read) | — | — | — | — | — | — | — | — |
| `IBLOGIN` | R (read) | — | — | — | — | — | — | — | — |
| `IBLOGOUT` | R (read) | — | — | — | — | — | — | — | — |
| `IBACSUM` | — | G (get) | G (get) | — | — | — | — | — | — |
| `IBTRAN` | — | G (get) | R (read) | I (insert) | — | — | — | — | — |
| `IBLOAD` | L (load) | L (load) | L (load) | L (load) | L (load) | L (load) | L (load) | L (load) | L (load) |
| `IB` (admin) | AP | AP | AP | AP | AP | AP | AP | AP | AP |

**PROCOPT key:** `G` = Get (read), `R` = Read, `I` = Insert, `L` = Load (initial load), `AP` = All Processing (full CRUD + admin)

**Key observations:**
- `IBGCUDAT` is the narrowest PSB in the system — one database, one segment, read-only
- No runtime program accesses `TSTATTYP`, `TTYPE`, or `CUSTTYPE` — these are reference tables populated once by `IBLOAD` and read by the Java layer
- `HISTORY` is write-only from COBOL (`IBTRAN` PROCOPT=`I`) — reads come from the Java JMP layer
- `IBGCUDAT` and `IBSCUDAT` are functionally identical (both read `CUSTOMER` root segment) but serve different transaction types — `IBGCUDAT` is an IMS MPP (Message Processing Program) communicating via I/O PCB; `IBSCUDAT` is the z/OS Connect-facing variant
