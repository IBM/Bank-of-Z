"""Run IMS provisioning with a region-scoped, verified cold-start reply."""

import logging
import re
import time

logger = logging.getLogger(__name__)


def ready_reply(text, ims_id):
    """Return one unambiguous reply ID for this IMS, never another region."""
    if not re.fullmatch(r"[A-Z$#@][A-Z0-9$#@]{0,3}", ims_id):
        raise ValueError("Invalid IMS identifier")
    pattern = (r"\*(\d+)\s+DFS(?:810A|996I)\s+\*?IMS READY\*?"
               r"[^\n]*\s" + re.escape(ims_id) + r"\s*$")
    replies = set(re.findall(pattern, text, re.MULTILINE))
    return next(iter(replies)) if len(replies) == 1 else None


def cold_start(ims_id, execute, read_spool, timeout=300, poll_interval=5):
    """Reply only to the target job and wait for its actual completion WTO."""
    ready_reply("", ims_id)  # Validate before constructing operator commands.
    job_name = ims_id + "CTL"
    activity = execute("D A," + job_name)
    if activity.rc:
        return False
    ids = set(re.findall(r"\bWUID=((?:JOB|STC)\d+)\b", activity.stdout_response))
    if len(ids) != 1:
        return False
    job_id = ids.pop()
    completed = re.compile(r"\bDFS994I\s+\*?COLD START COMPLETED\.?\s+"
                           + re.escape(ims_id) + r"\s*$", re.MULTILINE)
    deadline = time.monotonic() + timeout
    sent = False
    while time.monotonic() < deadline:
        if completed.search(read_spool(job_id)):
            logger.info("Verified IMS %s cold start completed in %s", ims_id, job_id)
            return True
        if not sent:
            outstanding = execute("D R,JOB=" + job_name)
            if outstanding.rc:
                return False
            reply = ready_reply(outstanding.stdout_response, ims_id)
            if reply:
                logger.info("Cold-starting only %s via reply %s", job_name, reply)
                response = execute("R " + reply + ",/NRE CHECKPOINT 0 FMT ALL.")
                if response.rc or "IEE600I" not in response.stdout_response:
                    return False
                sent = True
        time.sleep(poll_interval)
    logger.error("IMS %s did not report cold-start completion", ims_id)
    return False


def verified_cold_start(self):
    from zoautil_py import jobs, opercmd

    success = cold_start(
        self.ims_id, opercmd.execute,
        lambda job_id: jobs.read_output(job_id, dd_name="JESMSGLG"),
        timeout=max(300, self.timeout), poll_interval=self.poll_interval,
    )
    self.result["coldstart_completed"] = success
    self.result["coldstart_message"] = (
        "Verified target control-region DFS994I cold-start completion" if success
        else "Target control-region cold start did not complete"
    )
    return success


def main():
    # Keep the vendor's normal task graph and state handling. Replace only its
    # global-console reply selection, within this invocation of the CLI.
    from zconfig.tasks.ims.ims_startup import ImsStartup
    from zconfig.cli.cli import main as zconfig_main

    ImsStartup._coldstart_ims = verified_cold_start
    return zconfig_main()


if __name__ == "__main__":
    raise SystemExit(main())
