"""Local regression tests; no z/OS commands or provisioning are executed."""

import importlib.util
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from jinja2 import Environment, StrictUndefined

ROOT = Path(__file__).resolve().parents[1]


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / ".setup/lib" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


db2 = load("db2_provisioning")
config = load("config")
templates = load("render_template")


class ProvisioningTests(unittest.TestCase):
    def values(self, provision=True):
        with patch.dict(os.environ, USER="BOZTEST", REPO_NAME="Bank-of-Z"):
            source = config.load_config(ROOT / ".setup/config/config.yaml")
            if provision:
                source["cfg"].update(db2_provision="true", db2_ssid="DBD2")
            return config.render_config(source)

    def environment(self):
        values = self.values()
        exports = {"DB2_SSID": "ZB01", "DB2_HLQ": "DB2V13", "CICS_HLQ": "CICSTS63"}
        exports.update({"DB2_PROVISION_" + key.upper(): str(value)
                        for key, value in values["db2_provisioning"].items()})
        return exports

    def render(self, exports):
        return db2.prepare((ROOT / ".setup/zconfig/db2-provision.yaml").read_text(), exports)["db2"]

    def test_console_response_states(self):
        cases = [
            ("D A,ZB01MSTR", "unknown"),
            ("D A,ZB01MSTR\nIEE115I ZB01MSTR NOT FOUND", "inactive"),
            ("IEE115I ACTIVITY\nZB01MSTR ZB01MSTR STC 00042", "active"),
            ("ZB01MSTR ZB01MSTR IEFPROC NSW S A=003E PER=NO SMC=000\n"
             "WUID=STC00032 USERID=STCDB2", "active"),
            ("ZB01MSTR A=ZZZZ", "unknown"),
            ("OTHERMSR OTHERMSR STC 00042", "unknown"),
            ("ZB01MSTR2 ZB01MSTR2 STC 00042", "unknown"),
            ("ICH408I ZB01MSTR NOT AUTHORIZED", "unknown"),
            ("", "unknown"),
        ]
        for response, expected in cases:
            with self.subTest(response=response):
                self.assertEqual(db2.master_status(response, "ZB01"), expected)

    def test_wlm_console_response_states(self):
        for response, expected in [
            ("D WLM,APPLENV=DBD2WLM_REXX", "unknown"),
            (" DBD2WLM_REXX AVAILABLE\n ATTRIBUTES: PROC=DBD2WLMR", "AVAILABLE"),
            (" DBD2WLM_REXX QUIESCED", "QUIESCED"),
            (" DBD1WLM_REXX AVAILABLE", "unknown"),
            (" DBD2WLM_REXX AVAILABLE\n DBD2WLM_REXX QUIESCED", "unknown"),
        ]:
            self.assertEqual(db2.wlm_status(response, "DBD2WLM_REXX"), expected)

    def test_rexx_quiesce_restores_on_success_and_failure(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        helpers = script[script.index("read_db2_rexx_state() {"):script.index("stage_setup_cics_region() {")]
        harness = '''
print_success() { :; }
print_error() { printf '%s\\n' "$*" >&2; }
opercmd() {
    printf '%s\\n' "$*" >> "$COMMANDS"
    case "$*" in
        'D WLM,APPLENV=DBD2WLM_REXX') printf 'DBD2WLM_REXX %s\\n' "$(cat "$STATE")" ;;
        'V WLM,APPLENV=DBD2WLM_REXX,QUIESCE') printf QUIESCED > "$STATE" ;;
        'V WLM,APPLENV=DBD2WLM_REXX,RESUME') printf AVAILABLE > "$STATE" ;;
        *) return 1 ;;
    esac
}
'''
        for fail in (False, True):
            with self.subTest(fail=fail), tempfile.TemporaryDirectory() as work:
                state, commands = Path(work)/"state", Path(work)/"commands"
                state.write_text("AVAILABLE")
                suffix = "stage_quiesce_db2_rexx\n" + ("exit 7\n" if fail else "stage_resume_db2_rexx\n")
                result = subprocess.run(["bash"], input="set -e\n" + harness + helpers + suffix,
                                        text=True, capture_output=True,
                                        env=dict(os.environ, DB2_SSID="DBD2", STATE=str(state), COMMANDS=str(commands),
                                                 PYTHON_HOME=str(Path(sys.executable).parent.parent), SCRIPTS_DIR=str(ROOT/".setup")))
                self.assertEqual(result.returncode, 7 if fail else 0, result.stderr)
                self.assertEqual(state.read_text(), "AVAILABLE")
                issued = commands.read_text().splitlines()
                self.assertEqual(issued.count("V WLM,APPLENV=DBD2WLM_REXX,QUIESCE"), 1)
                self.assertEqual(issued.count("V WLM,APPLENV=DBD2WLM_REXX,RESUME"), 1)

    def test_rexx_quiesce_preserves_operator_state_and_rejects_unknown(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        helpers = script[script.index("read_db2_rexx_state() {"):script.index("stage_setup_cics_region() {")]
        for state, expected in (("QUIESCED", 0), ("unknown", 1)):
            harness = '''
print_error() { :; }
read_db2_rexx_state() { printf '%s\\n' "$INITIAL_STATE"; }
control_db2_rexx() { printf 'UNEXPECTED control\\n'; return 9; }
'''
            result = subprocess.run(["bash"], input=helpers + harness + "stage_quiesce_db2_rexx\n",
                                    text=True, capture_output=True,
                                    env=dict(os.environ, DB2_SSID="DBD2", INITIAL_STATE=state))
            self.assertEqual(result.returncode, expected, result.stderr)
            self.assertEqual(result.stdout, "")

    def test_new_environment_only_quiesces_after_db2_provisioning(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        setup = script[script.index("main_setup() {"):script.index("# STAGE: Validate Installation")]
        branch = setup[setup.index('    if [[ "${DB2_PROVISION}"'):setup.index("    stage_setup_database")]
        harness = '''
print_info() { :; }
stage_setup_db2_subsystem() { printf 'provision\\n'; }
stage_quiesce_db2_rexx() { printf 'quiesce\\n'; }
'''
        for provision in ("false", "true"):
            result = subprocess.run(["bash"], input=harness + branch, text=True, capture_output=True, check=True,
                                    env=dict(os.environ, DB2_PROVISION=provision, DB2_REPROVISION="false"))
            self.assertEqual(result.stdout, "provision\nquiesce\n" if provision == "true" else "")

    def test_catalog_override_and_default(self):
        values = self.environment()
        self.assertEqual(self.render(values)["catalog"], "DBD2")
        values["DB2_PROVISION_CATALOG"] = ""
        self.assertNotIn("catalog", self.render(values))
        values["DB2_PROVISION_CATALOG"] = "CUSTOM.CAT"
        self.assertEqual(self.render(values)["catalog"], "CUSTOM.CAT")

    def test_optional_sms_settings(self):
        values = self.environment()
        full = self.render(values)
        self.assertEqual(full["ssid"], "ZB01")
        self.assertEqual(full["volumes_and_sms_classes"]["volexit"], values["DB2_PROVISION_VOLUME"])
        for suffix in ("VOLUME", "STORAGE_CLASS", "DATA_CLASS"):
            values["DB2_PROVISION_" + suffix] = ""
        self.assertNotIn("volumes_and_sms_classes", self.render(values))
        values["DB2_PROVISION_STORAGE_CLASS"] = "SMSCLASS"
        self.assertEqual(set(self.render(values)["volumes_and_sms_classes"].values()), {"SMSCLASS"})

    def test_required_values_and_quoted_paths(self):
        values = self.environment()
        values["DB2_PROVISION_JAVA_HOME"] = '/tools/java "quoted" runtime'
        self.assertEqual(self.render(values)["db2_java_properties"]["javahome"], values["DB2_PROVISION_JAVA_HOME"])
        values["DB2_SSID"] = ""
        with self.assertRaises(ValueError):
            self.render(values)

    def test_configuration_compatibility(self):
        for module in (config, templates):
            for section in ("global", "cfg"):
                source = {section: {"user": "${USER}"}, "lower": "{{ " + section + ".user | lower }}"}
                with patch.dict(os.environ, USER="BOZTEST"):
                    result = module.render_config(module.normalize_config(source))
                self.assertEqual(result["lower"], "boztest")

    def test_literal_component_values_are_not_configuration_references(self):
        source = {"global": {"db2_provision": "false"},
                  "cics": {"host": "global.example.invalid"},
                  "ims": {"java_conf_path": "/u/demo/global.properties"},
                  "literal": "{{ 'global.properties' }}"}
        for module in (config, templates):
            values = module.render_config(module.normalize_config(source))
            self.assertEqual(values["cics"], source["cics"])
            self.assertEqual(values["ims"], source["ims"])
            self.assertEqual(values["literal"], "global.properties")

    def test_pre_provisioning_customer_config_can_render_the_environment(self):
        # Reconstruct the pre-feature configuration without depending on Git
        # history being available in a shallow CI checkout.
        source = config.yaml.safe_load((ROOT / ".setup/config/config.yaml").read_text())
        del source["db2_provisioning"]
        del source["global"]["db2_provision"]
        del source["global"]["db2_reprovision"]
        source["global"]["db2_runlib"] = "{{ global.db2_ssid }}.RUNLIB.LOAD"
        script = (ROOT / ".setup/config/setenv.sh").read_text()
        template = script.split("<<'EOF'\n", 1)[1].split("\nEOF", 1)[0]
        for module in (config, templates):
            values = module.render_config(module.normalize_config(source))
            rendered = Environment(undefined=StrictUndefined).from_string(template).render(values)
            self.assertIn('DB2_PROVISION="${DB2_PROVISION:-false}"', rendered)
            self.assertEqual(values["db2"]["runlib"], "DBD1.RUNLIB.LOAD")
            db2.validate_bank_config(values, {})
            subprocess.run(["bash", "-n"], input=rendered, text=True, check=True)

    def test_full_bank_phases_reject_conflicting_db2_identity_before_actions(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        main = "main() {" + script.split("main() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
        values = self.values(provision=False)
        for name, value in (("DB2_SSID", "ZZ99"), ("DB2_HLQ", "OTHER"),
                            ("DB2_PROVISION", "true"), ("DB2_JAVA_FOLDER", "/other")):
            with self.subTest(name=name), self.assertRaisesRegex(ValueError, name):
                db2.validate_bank_config(values, {name: value})
        harness = '''
detect_bank_of_z_location() { printf 'UNEXPECTED action\\n'; }
main_validation() { printf 'UNEXPECTED validation\\n'; }
main_setup() { printf 'UNEXPECTED setup\\n'; }
main_verify_installation() { printf 'UNEXPECTED verification\\n'; }
'''
        for phase in ("environment", "install-bank-of-z", "verify-installation"):
            result = subprocess.run(["bash"], input=harness + main + '\nmain "$PHASE"\n',
                                    text=True, capture_output=True,
                                    env=dict(os.environ, DB2_SSID="ZZ99", DB2_PROVISION="false", PHASE=phase,
                                             CONFIG_FILE=str(ROOT/".setup/config/config.yaml"),
                                             PYTHON_HOME=str(Path(sys.executable).parent.parent),
                                             SCRIPTS_DIR=str(ROOT/".setup")))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("DB2_SSID disagrees", result.stderr)
            self.assertEqual(result.stdout, "")

    def test_matching_bank_identity_and_sql_use_the_new_subsystem(self):
        values = self.values()
        db2.validate_bank_config(values, {"DB2_SSID": "DBD2", "DB2_HLQ": "DB2V13", "DB2_PROVISION": "true"})
        rendered = templates.render_template(str(ROOT/".setup/jcl/cics/Db2-drop.j2"), values)
        self.assertIn("DSN SYSTEM(DBD2)", rendered)
        self.assertIn("LIB('DB2V13.DBD2.RUNLIB.LOAD')", rendered)

    def test_standalone_provisioning_rejects_conflicting_identity_before_actions(self):
        with tempfile.TemporaryDirectory() as work:
            work = Path(work)
            for directory in ("setup", "config", "lib"):
                (work/directory).mkdir()
            for path in ("setup/setup-db2-subsystem.sh", "lib/db2-status.sh", "lib/db2_provisioning.py", "lib/config.py"):
                shutil.copyfile(ROOT/".setup"/path, work/path)
            (work/"config/setenv.sh").write_text("opercmd() { printf 'UNEXPECTED z/OS command\\n'; }\n")
            result = subprocess.run(["bash", str(work/"setup/setup-db2-subsystem.sh")], text=True, capture_output=True,
                                    env=dict(os.environ, CONFIG_FILE=str(ROOT/".setup/config/config.yaml"),
                                             PYTHON_HOME=str(Path(sys.executable).parent.parent), DB2_SSID="ZZ99"))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("DB2_SSID disagrees", result.stderr)
            self.assertEqual(result.stdout, "")

    def test_nested_environment_references_before_filters(self):
        source = {"cfg": {"user": "${BOZ_TEST_USER}"},
                  "path": "/u/{{ cfg.user | lower }}/java"}
        variables = {"BOZ_TEST_USER": "${BOZ_TEST_ACCOUNT}", "BOZ_TEST_ACCOUNT": "BOZTEST"}
        for module in (config, templates):
            with patch.dict(os.environ, variables):
                self.assertEqual(module.render_config(source)["path"], "/u/boztest/java")

    def test_deployment_parameters(self):
        values = self.values()
        settings = values["db2_provisioning"]
        admin_user = values["cfg"]["zos_admin_user"]
        expected = {
            "catalog": "DBD2", "storage_class": "SGDB213",
            "user_catalog": "CATALOG.VS01.DB2V13", "volume": "DB2V13",
            "data_class": "DCDB2EXT", "authid": admin_user,
            "javaenv": "DBD2.DSN1WLMJ.JAVAENV",
            "javaenvv": f"/u/{admin_user.lower()}/dbd2envfile.txt",
            "jvmprops": f"/u/{admin_user.lower()}/dbd2jvmsp",
            "sdsnexit": "DB2V13.DBD2.SDSNEXIT",
        }
        for key, value in expected.items():
            self.assertEqual(settings[key], value, key)
        self.assertEqual(settings["java_home"], values["java"]["java_home"])
        self.assertEqual(values["db2"]["runlib"], "DB2V13.DBD2.RUNLIB.LOAD")

    def test_environment_template_and_defaults(self):
        values = self.values()
        self.assertEqual(values["cfg"]["db2_provision"], "true")
        self.assertEqual(values["cfg"]["db2_ssid"], "DBD2")
        script = (ROOT / ".setup/config/setenv.sh").read_text()
        template = script.split("<<'EOF'\n", 1)[1].split("\nEOF", 1)[0]
        output = Environment(undefined=StrictUndefined).from_string(template).render(values)
        self.assertNotIn("{{", output)
        subprocess.run(["bash", "-n"], input=output, text=True, check=True)

    def test_existing_subsystem_is_the_opt_out_default(self):
        values = self.values(provision=False)
        self.assertEqual(values["cfg"]["db2_provision"], "false")
        self.assertEqual(values["db2"]["ssid"], "DBD1")
        self.assertEqual(values["db2"]["runlib"], "DBD1.RUNLIB.LOAD")

    def test_cics_connection_rewrite_requires_a_db2_selection(self):
        script = (ROOT / ".setup/setup/setup-cics-region.sh").read_text()
        rewrite = script[script.index('if [[ "${DB2_PROVISION:-false}"'):script.index("# Cleanup\n")]
        source = (ROOT / ".setup/zconfig/bank-of-z-definitions.yaml").read_text()
        source += '\n# An unrelated resource must keep its original identifier.\n- program:\n    name: DBD1\n'
        for provision, ssid in [("false", "DBD1"), ("false", "CUSTOM"), ("true", "DBD1"), ("true", "DBD2")]:
            with self.subTest(provision=provision, ssid=ssid), tempfile.TemporaryDirectory() as work:
                definition = Path(work) / "definitions.yaml"
                definition.write_text(source)
                subprocess.run(["bash"], input='set -e\nchtag() { :; }\n' + rewrite,
                               text=True, capture_output=True, check=True,
                               env=dict(os.environ, DB2_PROVISION=provision, DB2_SSID=ssid,
                                        DEFINITION_FILE=str(definition), BACKUP_FILE=str(definition) + ".back",
                                        PYTHON_HOME=str(Path(sys.executable).parent.parent)))
                expected = source if provision == "false" and ssid == "DBD1" else source.replace("{{ vars.db2_ssid }}", ssid)
                self.assertEqual(definition.read_text(), expected)
                if provision == "true" or ssid != "DBD1":
                    self.assertEqual(Path(str(definition) + ".back").read_text(), source)

    def test_status_query_failures_stop_the_caller(self):
        env = dict(os.environ, SCRIPTS_DIR=str(ROOT / ".setup/setup"),
                   PYTHON_HOME=str(Path(sys.executable).parent.parent), DB2_SSID="ZB01")
        script = '''
source "$SCRIPTS_DIR/../lib/db2-status.sh"
print_error() { printf '%s\\n' "$*" >&2; }
opercmd() { printf '%s\\n' "$RESPONSE"; return "$QUERY_RC"; }
read_db2_master_status
'''
        for response, rc, expected in [
            ("ZB01MSTR ZB01MSTR STC 42", "0", "active"),
            ("ZB01MSTR NOT FOUND", "0", "inactive"),
            ("ZB01MSTR NOT FOUND", "8", None),
            ("D A,ZB01MSTR", "0", None),
        ]:
            with self.subTest(response=response, rc=rc):
                result = subprocess.run(["bash"], input=script, text=True, capture_output=True,
                                        env=dict(env, RESPONSE=response, QUERY_RC=rc))
                if expected:
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout.strip(), expected)
                else:
                    self.assertNotEqual(result.returncode, 0)

    def test_cached_environment_preserves_explicit_lifecycle_options(self):
        script = (ROOT / ".setup/config/setenv.sh").read_text()
        template = script.split("<<'EOF'\n", 1)[1].split("\nEOF", 1)[0]
        cached = Environment(undefined=StrictUndefined).from_string(template).render(self.values())
        test = ('set -e\nDB2_REPROVISION=true\nDB2_PROVISION_CATALOG=CUSTOM\n'
                + 'get_section_value() { printf DBD2; }\n'
                + cached
                + '\n[[ "$DB2_SSID" == DBD2 && "$DB2_PROVISION" == true ]]\n'
                + '[[ "$DB2_REPROVISION" == true ]]\n'
                + '[[ "$DB2_PROVISION_CATALOG" == CUSTOM ]]\n'
                + '[[ "$DB2_PROVISION_JAVAENVV" == *dbd2* ]]\n')
        subprocess.run(["bash"], input=test, text=True, check=True)

    def test_cached_environment_preserves_an_explicit_empty_catalog(self):
        script = (ROOT / ".setup/config/setenv.sh").read_text()
        template = script.split("<<'EOF'\n", 1)[1].split("\nEOF", 1)[0]
        cached = Environment(undefined=StrictUndefined).from_string(template).render(self.values())
        for supplied, expected in ((None, "DBD2"), ("", ""), ("CUSTOM", "CUSTOM")):
            prefix = 'unset DB2_PROVISION_CATALOG\n' if supplied is None else f'DB2_PROVISION_CATALOG="{supplied}"\n'
            harness = ('set -e\nget_section_value() { printf DBD2; }\n' + prefix
                       + cached
                       + '\nprintf "%s" "$DB2_PROVISION_CATALOG"\n')
            result = subprocess.run(["bash"], input=harness, text=True, capture_output=True, check=True)
            self.assertEqual(result.stdout, expected)

    def test_cics_db2_preparation_failures_restore_definitions_before_cleanup(self):
        original = 'db2id: "{{ vars.db2_ssid }}"\n'
        for step in ("backup", "binary_tag", "python", "utf8_tag"):
            with self.subTest(step=step), tempfile.TemporaryDirectory() as work:
                work = Path(work)
                for directory in ("setup", "config", "zconfig"):
                    (work/directory).mkdir()
                script = work/"setup/setup-cics-region.sh"
                shutil.copyfile(ROOT/".setup/setup/setup-cics-region.sh", script)
                definition = work/"zconfig/bank-of-z-definitions.yaml"
                definition.write_text(original)
                (work/"zconfig/debug-definitions.yaml").write_text("debug: unchanged\n")
                (work/"config/setenv.sh").write_text('''
CYAN= NC= ZCONFIG_HOME= ZCONFIG_ZCB_HOME= ZOAU_HOME= LIBPATH=
APP_HLQ=BANKZ
print_error() { printf '%s\\n' "$*"; }
chtag() {
    [[ "$1" == -p ]] && { printf 't UTF-8 T=on\\n'; return 0; }
    [[ "$FAIL_STEP" == binary_tag && "$1" == -b ]] && return 8
    [[ "$FAIL_STEP" == utf8_tag && "$1" == -tc ]] && return 8
    return 0
}
cp() {
    if [[ "$FAIL_STEP" == backup ]]; then printf partial > "$2"; return 8; fi
    command cp "$@"
}
opercmd() { printf 'UNEXPECTED CICS cancellation\\n'; }
''')
                python_home = "/nonexistent-bankz-test-python" if step == "python" else str(Path(sys.executable).parent.parent)
                result = subprocess.run(["bash", str(script)], text=True, capture_output=True,
                                        env=dict(os.environ, FAIL_STEP=step, DB2_PROVISION="true", DB2_SSID="ZZ99",
                                                 PYTHON_HOME=python_home))
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("UNEXPECTED", result.stdout + result.stderr)
                self.assertEqual(definition.read_text(), original)

    def test_deprovision_checks_ownership_and_consumers_without_stopping_them(self):
        cases = [
            ({}, True, True),
            ({"IMS_DISABLED": "true"}, True, True),
            ({"DB2_SSID": "OTHER"}, False, False),
            ({"DB2_DEPROVISION_CONFIRM": "WRONG"}, False, False),
            ({"MANAGED_URI": "db2://ZZ990"}, False, False),
            ({"INITIAL_LIST_FAIL": "true"}, False, False),
            ({"ACTIVE_TASK": "CICSBOZ"}, False, False),
            ({"ACTIVE_TASK": "IMS2MPP1"}, False, False),
            ({"UNKNOWN_TASK": "IMS2CTL"}, False, False),
            ({"QUERY_FAIL_TASK": "CICSBOZ"}, False, False),
            ({"FINAL_LIST_FAIL": "true"}, False, True),
            ({"KEEP_STATE": "true"}, False, True),
            ({"REMOVE_FAIL": "true"}, False, True),
            ({"ACTIVE_TASK": "ZZ99MSTR"}, False, True),
        ]
        for overrides, success, removed in cases:
            with self.subTest(overrides=overrides), tempfile.TemporaryDirectory() as work:
                work = Path(work)
                for directory in ("setup", "config", "lib", "tool/bin"):
                    (work/directory).mkdir(parents=True)
                for path in ("setup/deprovision-db2-subsystem.sh", "lib/db2-status.sh", "lib/db2_provisioning.py", "lib/config.py"):
                    shutil.copyfile(ROOT/".setup"/path, work/path)
                values = config.yaml.safe_load((ROOT/".setup/config/config.yaml").read_text())
                values["global"]["db2_ssid"] = "ZZ99"
                (work/"config.yaml").write_text(config.yaml.safe_dump(values))
                (work/"config/setenv.sh").write_text('''
CYAN= NC= ZOAU_HOME= LIBPATH=
print_stage() { :; }
print_warning() { :; }
print_info() { printf '%s\\n' "$*"; }
print_error() { printf 'ERROR: %s\\n' "$*"; }
print_success() { printf 'SUCCESS: %s\\n' "$*"; }
opercmd() {
    printf 'opercmd %s\\n' "$*" >> "$EVENTS"
    local task="${1##*,}"
    [[ "$task" == "${QUERY_FAIL_TASK:-}" ]] && return 8
    [[ "$task" == "${UNKNOWN_TASK:-}" ]] && { printf '%s\\n' "$*"; return 0; }
    if [[ "$task" == "${ACTIVE_TASK:-}" ]]; then
        printf '%s %s STC 00042\\n' "$task" "$task"
    else
        printf 'IEE115I %s NOT FOUND\\n' "$task"
    fi
}
''')
                (work/"tool/bin/activate").write_text('''
deactivate() { :; }
zconfig() {
    printf 'zconfig %s\\n' "$*" >> "$EVENTS"
    case "$1" in
        ls)
            if [[ -f "$REMOVED" ]]; then
                [[ "${FINAL_LIST_FAIL:-}" == true ]] && return 8
                [[ "${KEEP_STATE:-}" == true ]] && printf '%s\\n' "$MANAGED_URI"
            else
                [[ "${INITIAL_LIST_FAIL:-}" == true ]] && return 8
                printf '│ %s │ managed │\\n' "$MANAGED_URI"
            fi
            return 0 ;;
        rm)
            touch "$REMOVED"
            [[ "${REMOVE_FAIL:-}" == true ]] && return 8
            return 0 ;;
        *) return 9 ;;
    esac
}
''')
                env = dict(os.environ, DB2_SSID="ZZ99", DB2_DEPROVISION_CONFIRM="ZZ99", APP_SHORT_NAME="BOZ",
                           IMS_DISABLED="false", IMS_DATASTORE="IMS2", ZCONFIG_HOME=str(work/"tool"),
                           CONFIG_FILE=str(work/"config.yaml"), DB2_PROVISION="false",
                           PYTHON_HOME=str(Path(sys.executable).parent.parent), EVENTS=str(work/"events"),
                           REMOVED=str(work/"removed"), MANAGED_URI="db2://ZZ99")
                env.update(overrides)
                result = subprocess.run(["bash", str(work/"setup/deprovision-db2-subsystem.sh")],
                                        text=True, capture_output=True, env=env)
                self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
                self.assertEqual((work/"removed").exists(), removed)
                self.assertEqual("SUCCESS:" in result.stdout, success, result.stdout)
                events = (work/"events").read_text() if (work/"events").exists() else ""
                if removed:
                    queries = events.split("zconfig rm", 1)[0]
                    self.assertIn("opercmd D A,CICSBOZ", queries)
                    if env["IMS_DISABLED"] != "true":
                        self.assertIn("opercmd D A,IMS2MPP2", queries)
                if overrides.get("MANAGED_URI") or overrides.get("INITIAL_LIST_FAIL"):
                    self.assertNotIn("opercmd", events)
                for line in events.splitlines():
                    self.assertTrue(line.startswith(("opercmd D A,", "zconfig ls", "zconfig rm db2://ZZ99 -v --ie")), line)

    def test_only_fresh_db2_setup_skips_the_existing_legacy_ims_cleanup(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        stop = "stage_stop_tasks() {" + script.split("stage_stop_tasks() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
        with tempfile.TemporaryDirectory() as work:
            runtime = Path(work) / ".setup/runtime-manage.sh"
            runtime.parent.mkdir()
            runtime.touch()
            harness = '''
print_stage() { :; }
print_info() { :; }
print_error() { :; }
bash() { printf 'runtime:%s\\n' "$*"; }
jcan() { printf 'legacy:%s\\n' "$*"; }
drm() { :; }
rm() { :; }
dtouch() { :; }
sleep() { :; }
APP_HLQ=BANKZ
APP_ZOS_VERSION=V0R1M0
APP_SHORT_NAME=BOZ
SANDBOX_DIR=/test-sandbox
'''
            for provision in ("false", "true"):
                result = subprocess.run(["bash"], input=harness + stop + "\nstage_stop_tasks\n",
                                        text=True, capture_output=True,
                                        env=dict(os.environ, BANK_DIR=work, DB2_PROVISION=provision))
                self.assertEqual(result.returncode, 0, result.stderr)
                expected = "runtime:.setup/runtime-manage.sh stop all\n"
                if provision == "false":
                    expected += "legacy:P IMS1*\n"
                self.assertEqual(result.stdout, expected)

    def test_db2_removal_entrypoint_does_not_call_shared_stop_or_cleanup(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        helper = "stage_deprovision_db2_subsystem() {" + script.split("stage_deprovision_db2_subsystem() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
        with tempfile.TemporaryDirectory() as work:
            child = Path(work)/".setup/setup/deprovision-db2-subsystem.sh"
            child.parent.mkdir(parents=True)
            child.write_text("#!/bin/bash\nprintf 'db2-only\\n'\n")
            child.chmod(0o700)
            harness = '''
print_stage() { :; }
print_info() { :; }
print_error() { :; }
print_success() { :; }
stage_stop_tasks() { printf 'UNEXPECTED shared shutdown\\n'; return 9; }
'''
            result = subprocess.run(["bash"], input='set -e\n' + harness + helper + "\nstage_deprovision_db2_subsystem\n",
                                    text=True, capture_output=True,
                                    env=dict(os.environ, BANK_DIR=work, DB2_SSID="DBD2", DB2_DEPROVISION_CONFIRM="DBD2"))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "db2-only\n")

    def test_deprovision_confirmation_precedes_service_shutdown(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        helper = "stage_deprovision_db2_subsystem() {" + script.split("stage_deprovision_db2_subsystem() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
        harness = '''
print_stage() { :; }
print_error() { :; }
stage_stop_tasks() { printf 'UNEXPECTED shutdown\\n'; }
'''
        for confirmation in ("", "DBD1"):
            result = subprocess.run(["bash"], input=harness + helper + "\nstage_deprovision_db2_subsystem\n",
                                    text=True, capture_output=True,
                                    env=dict(os.environ, DB2_SSID="DBD2", DB2_DEPROVISION_CONFIRM=confirmation))
            self.assertEqual(result.returncode, 2, result.stderr)
            self.assertEqual(result.stdout, "")


if __name__ == "__main__":
    unittest.main()
