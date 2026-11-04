"""Local regression tests; no z/OS commands or provisioning are executed."""

import importlib.util
import os
from pathlib import Path
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

    def test_build_libraries_follow_the_effective_provisioning_switch(self):
        original = {"SDFHPL1": "DFH.V6R2M24P.CICS.SDFHPL1",
                    "SCSQCOBC": "CSQ.V9R1M0.SCSQCOBC",
                    "SCSQPLIC": "CSQ.V9R3M0.SCSQPLIC",
                    "SCSQMACS": "CSQ.V9R3M0.SCSQMACS",
                    "SCSQLOAD": "CSQ.V9R1M0.SCSQLOAD"}
        for provision in ("false", "true"):
            # Deliberately override the opposite config value, as callers can.
            values = self.values(provision=provision == "false")
            values.update(db2_provision=provision)
            values["cics"]["cics_hlq"] = "OTHER.CICS"
            values["mq"]["install_hlq"] = "OTHER.MQ"
            rendered = templates.render_template(ROOT / ".setup/build/datasets.yaml.j2", values)
            import yaml
            libraries = {entry["name"]: entry["value"] for entry in yaml.safe_load(rendered)["variables"]}
            expected = original if provision == "false" else {
                key: "OTHER.CICS.CICS.SDFHPL1" if key == "SDFHPL1" else "OTHER.MQ." + key
                for key in original}
            self.assertEqual({key: libraries[key] for key in original}, expected)

    def test_cics_jvm_timeouts_require_new_db2(self):
        profile = (ROOT / ".setup/zconfig/EYUSMSSJ.jvmprofile").read_text()
        values = dict(java_home="/java", region_uss_dir="/sandbox", cics_uss_dir="/cics")
        for provision in (None, "false", "true"):
            variables = dict(values)
            if provision is not None:
                variables["db2_provision"] = provision
            rendered = Environment(undefined=StrictUndefined).from_string(profile).render(vars=variables)
            self.assertEqual("OSGI_FRAMEWORK_TIMEOUT=600" in rendered, provision == "true")
            self.assertEqual("controller.timeout=600000" in rendered, provision == "true")

    def test_ims_startup_wrapper_is_only_selected_for_new_db2(self):
        script = (ROOT / ".setup/setup/setup-ims-region.sh").read_text()
        selection = script[script.index("IMS_ZCONFIG_COMMAND=(zconfig)"):script.index('"${IMS_ZCONFIG_COMMAND[@]}" apply')]
        for provision in (None, "false", "true"):
            env = dict(os.environ, SCRIPTS_DIR="/test/setup")
            env.pop("DB2_PROVISION", None)
            if provision is not None:
                env["DB2_PROVISION"] = provision
            result = subprocess.run(["bash"], input=selection + '\nprintf "%s\\n" "${IMS_ZCONFIG_COMMAND[@]}"\n',
                                    text=True, capture_output=True, env=env, check=True)
            expected = ["python3", "/test/setup/../lib/ims_provisioning.py"] if provision == "true" else ["zconfig"]
            self.assertEqual(result.stdout.splitlines(), expected)

    def test_cics_startup_reply_requires_both_opt_ins(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        stage = "stage_setup_cics_region() {" + script.split("stage_setup_cics_region() {", 1)[1].split("\n}\n", 1)[0] + "\n}\n"
        with tempfile.TemporaryDirectory() as work:
            setup = Path(work) / ".setup/setup/setup-cics-region.sh"
            setup.parent.mkdir(parents=True)
            setup.write_text("exit 0\n")
            setup.chmod(0o700)
            harness = '''
print_stage() { :; }
print_info() { :; }
print_success() { :; }
wait_for_cics_cmci() { printf 'waited\\n'; }
'''
            for provision in ("false", "true"):
                for auto_reply in ("false", "true"):
                    result = subprocess.run(["bash"], input=harness + stage + "\nstage_setup_cics_region\n",
                                            text=True, capture_output=True, check=True,
                                            env=dict(os.environ, BANK_DIR=work, DB2_PROVISION=provision,
                                                     CICS_AUTO_REPLY_GO=auto_reply))
                    self.assertEqual(result.stdout, "waited\n" if provision == auto_reply == "true" else "")

    def test_ims_compression_is_only_in_the_generated_db2_profile(self):
        import yaml
        source = (ROOT / ".setup/deploy/Development.yml").read_text()
        original = yaml.safe_load(source)
        self.assertNotIn("compression", original["ims_acb_gen_default"])
        generated = db2.deployment_environment(source)
        self.assertEqual(generated["ims_acb_gen_default"].pop("compression"), "PRECOMP,POSTCOMP")
        self.assertEqual(generated, original)

    def test_db2_deployment_profile_preserves_custom_ims_settings(self):
        source = 'ims_acb_gen_default:\n  compression: POSTCOMP\n'
        self.assertEqual(db2.deployment_environment(source)["ims_acb_gen_default"]["compression"], "POSTCOMP")
        self.assertEqual(db2.deployment_environment("kind: Environment\n"), {"kind": "Environment"})

    def test_deployment_profile_selection_preserves_the_original_when_disabled(self):
        script = (ROOT / ".setup/tasks/task-wazi-deploy.sh").read_text()
        selection = script[script.index('deployment_env_file="$DEPLOY_ENV_FILE"'):script.index('CMD="wazideploy-deploy')]
        harness = '''
PYTHON_HOME=/unused
chtag() { printf 'UNEXPECTED tag\\n'; }
'''
        result = subprocess.run(["bash"], input=harness + selection + '\nprintf "%s\\n" "$deployment_env_file"\n',
                                text=True, capture_output=True, check=True,
                                env=dict(os.environ, DB2_PROVISION="false", DEPLOY_ENV_FILE="/original/Development.yml"))
        self.assertEqual(result.stdout, "/original/Development.yml\n")

    def test_enabled_deployment_selects_a_separate_profile_and_keeps_jinja(self):
        import yaml
        script = (ROOT / ".setup/tasks/task-wazi-deploy.sh").read_text()
        selection = script[script.index('deployment_env_file="$DEPLOY_ENV_FILE"'):script.index('CMD="wazideploy-deploy')]
        original_path = ROOT / ".setup/deploy/Development.yml"
        original = original_path.read_bytes()
        with tempfile.TemporaryDirectory() as work:
            result = subprocess.run(["bash"], input='set -e\nchtag() { :; }\n' + selection + '\nprintf "%s\\n" "$deployment_env_file"\n',
                                    text=True, capture_output=True, check=True,
                                    env=dict(os.environ, DB2_PROVISION="true", OUTPUT_FOLDER=work,
                                             PYTHON_HOME=str(Path(sys.executable).parent.parent),
                                             SCRIPTS_DIR=str(ROOT / ".setup/tasks"), DEPLOY_ENV_FILE=str(original_path)))
            generated = yaml.safe_load(Path(result.stdout.strip()).read_text())
            self.assertEqual(generated["ims_acb_gen_default"].pop("compression"), "PRECOMP,POSTCOMP")
            self.assertEqual(generated, yaml.safe_load(original))
        self.assertEqual(original_path.read_bytes(), original)

    def test_cics_connection_rewrite_requires_a_db2_selection(self):
        script = (ROOT / ".setup/setup/setup-cics-region.sh").read_text()
        rewrite = script[script.index('if [[ "${DB2_PROVISION:-false}"'):script.index("# Cleanup\n")]
        source = '- db2conn:\n    name: "{{ vars.db2_ssid }}"\n    db2id: "{{ vars.db2_ssid }}"\n'
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

    def test_cached_lifecycle_and_catalog_overrides(self):
        script = (ROOT / ".setup/config/setenv.sh").read_text()
        snapshot = script[script.index("_BANKZ_CALLER_OVERRIDES=()"):script.index("# A profile can clear USER.")]
        restore = script[script.index("_BANKZ_CONFIG_DB2_SSID="):script.index("# List of variables to check")]
        template = script.split("<<'EOF'\n", 1)[1].split("\nEOF", 1)[0]
        cached = Environment(undefined=StrictUndefined).from_string(template).render(self.values())
        test = ('set -e\nDB2_SSID=ZZ99\nDB2_PROVISION=true\nDB2_PROVISION_CATALOG=CUSTOM\n'
                + 'get_section_value() { printf DBD2; }\n'
                + snapshot + '\n' + cached
                + '\nDB2_PROVISION_CATALOG=STALE\n' + restore
                + '\n[[ "$DB2_SSID" == ZZ99 && "$DB2_PROVISION" == true ]]\n'
                + '[[ "$DB2_PROVISION_CATALOG" == CUSTOM ]]\n'
                + '[[ "$DB2_PROVISION_JAVAENVV" == *zz99* ]]\n')
        subprocess.run(["bash"], input=test, text=True, check=True)

    def test_cics_readiness_accepts_zos_and_linux_listeners(self):
        script = (ROOT / ".setup/setup-common.sh").read_text()
        helper = "wait_for_cics_cmci() {" + script.split("wait_for_cics_cmci() {", 1)[1].split("\nstage_setup_cics_region()", 1)[0]
        harness = '''
print_info() { :; }
print_success() { :; }
print_error() { :; }
netstat() { printf '%s\\n' "$RESPONSE"; }
opercmd() { :; }
sleep() { :; }
APP_SHORT_NAME=BOZ
CICS_CMCI_PORT=27100
CICS_CMCI_START_TIMEOUT_SECONDS=5
'''
        cases = [
            ("CICSBOZ 00000001 0.0.0.0..27100 0.0.0.0..0 Listen", True),
            ("tcp 0 0 0.0.0.0:27100 0.0.0.0:* LISTEN", True),
            ("CICSBOZ 00000001 0.0.0.0..271001 0.0.0.0..0 Listen", False),
            ("CICSBOZ 00000001 0.0.0.0..27100 0.0.0.0..0 Establsh", False),
        ]
        for response, expected in cases:
            with self.subTest(response=response):
                result = subprocess.run(["bash"], input=harness + helper + "\nwait_for_cics_cmci\n",
                                        text=True, capture_output=True,
                                        env=dict(os.environ, RESPONSE=response))
                self.assertEqual(result.returncode == 0, expected, result.stderr)

    def test_stopping_consumers_does_not_delete_resources_or_cancel_base_ims(self):
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
jcan() { printf 'UNEXPECTED cancellation:%s\\n' "$*"; }
drm() { printf 'UNEXPECTED dataset removal:%s\\n' "$*"; }
rm() { printf 'UNEXPECTED file removal:%s\\n' "$*"; }
dtouch() { :; }
sleep() { :; }
APP_HLQ=BANKZ
APP_ZOS_VERSION=V0R1M0
APP_SHORT_NAME=BOZ
SANDBOX_DIR=/test-sandbox
'''
            result = subprocess.run(["bash"], input=harness + stop + "\nstage_stop_tasks\n",
                                    text=True, capture_output=True,
                                    env=dict(os.environ, BANK_DIR=work))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), "runtime:.setup/runtime-manage.sh stop all")

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
