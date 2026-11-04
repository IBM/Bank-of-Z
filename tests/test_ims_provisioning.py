"""Check IMS console routing without issuing any z/OS commands."""

import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    "ims_provisioning", Path(__file__).resolve().parents[1] / ".setup/lib/ims_provisioning.py")
ims = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ims)


class ImsStartupTests(unittest.TestCase):
    def test_reply_is_scoped_to_target_among_other_regions(self):
        response = ("0007 R *0007 DFS996I *IMS READY* IVP1\n"
                    "0011 R *0011 DFS996I *IMS READY* IMS2\n")
        self.assertEqual(ims.ready_reply(response, "IMS2"), "0011")
        self.assertIsNone(ims.ready_reply(response, "IMS3"))

    def test_initial_prompt_and_prefix_collisions(self):
        response = "0010 R *0010 DFS810A IMS READY 26308/0305546 IMS2CTL.IEFPROC IMS2\n"
        self.assertEqual(ims.ready_reply(response, "IMS2"), "0010")
        self.assertIsNone(ims.ready_reply(response.replace(" IMS2\n", " IMS20\n"), "IMS2"))
        with self.assertRaises(ValueError):
            ims.ready_reply(response, "IMS2,ALL")

    def test_ambiguous_prompts_are_not_answered(self):
        response = ("*0010 DFS996I *IMS READY* IMS2\n"
                    "*0011 DFS996I *IMS READY* IMS2\n")
        self.assertIsNone(ims.ready_reply(response, "IMS2"))

    def test_reply_acceptance_is_not_restart_completion(self):
        execute = Mock(side_effect=[
            SimpleNamespace(rc=0, stdout_response="WUID=JOB00136 USERID=IBMUSER"),
            SimpleNamespace(rc=0, stdout_response="*0011 DFS996I *IMS READY* IMS2"),
            SimpleNamespace(rc=0, stdout_response="IEE600I REPLY TO 0011"),
        ])
        with patch.object(ims.time, "monotonic", side_effect=[0, 0, 301]), patch.object(ims.time, "sleep"):
            self.assertFalse(ims.cold_start("IMS2", execute, lambda job: "DFS3626I RESTART HAS BEEN ABORTED IMS2"))
        self.assertEqual(execute.call_args_list[1].args, ("D R,JOB=IMS2CTL",))
        self.assertEqual(execute.call_args_list[2].args, ("R 0011,/NRE CHECKPOINT 0 FMT ALL.",))

    def test_existing_completed_target_is_not_cold_started_again(self):
        execute = Mock(return_value=SimpleNamespace(rc=0, stdout_response="WUID=JOB00136 USERID=IBMUSER"))
        spool = "DFS994I COLD START COMPLETED. IMS2\n"
        self.assertTrue(ims.cold_start("IMS2", execute, lambda job: spool))
        execute.assert_called_once_with("D A,IMS2CTL")

    def test_query_failure_prevents_any_reply(self):
        execute = Mock(return_value=SimpleNamespace(rc=8, stdout_response="NOT AUTHORIZED"))
        self.assertFalse(ims.cold_start("IMS2", execute, Mock()))
        execute.assert_called_once_with("D A,IMS2CTL")


if __name__ == "__main__":
    unittest.main()
