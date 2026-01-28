import inspect
import json
from pathlib import Path
from typing import Any

from _nebari.stages.base import NebariTerraformStage
from nebari.hookspecs import NebariStage, hookimpl
from nebari.schema import Base
from pydantic import Field

try:
    from nebari_jupyterlite_plugin._version import __version__
except ImportError:
    __version__ = "unknown"


class JupyterLiteInputSchema(Base):
    enabled: bool = True
    auth_enabled: bool = True
    overrides: dict[str, Any] | None = {}


class InputSchema(Base):
    jupyterlite: JupyterLiteInputSchema = Field(default=JupyterLiteInputSchema())


class JupyterLiteStage(NebariTerraformStage):
    name = "jupyterlite"
    priority = 90
    input_schema = InputSchema

    @property
    def template_directory(self):
        return Path(inspect.getfile(self.__class__)).parent / "template" / self.config.provider.value

    def check(self, stage_outputs: dict[str, dict[str, Any]], disable_prompt=False) -> bool:
        # JupyterLite is a static web app, so it works on all providers
        # We just need to verify the ingress domain is available
        try:
            _ = stage_outputs["stages/04-kubernetes-ingress"]["domain"]
        except KeyError:
            print("\nPrerequisite stage output not found: stages/04-kubernetes-ingress domain")
            return False

        # Check forward auth is available if auth is enabled
        if self.config.jupyterlite.auth_enabled:
            try:
                _ = stage_outputs["stages/07-kubernetes-services"]["forward-auth-middleware"]["value"]["name"]
            except KeyError:
                print(
                    "\nPrerequisite stage output not found: forward-auth-middleware. "
                    "Set auth_enabled: false to disable authentication."
                )
                return False

        return True

    def input_vars(self, stage_outputs: dict[str, dict[str, Any]]):
        external_url = stage_outputs["stages/04-kubernetes-ingress"]["domain"]

        # Get forward auth middleware info if auth is enabled
        forwardauth_middleware_name = ""
        if self.config.jupyterlite.auth_enabled:
            forwardauth_middleware_name = stage_outputs["stages/07-kubernetes-services"]["forward-auth-middleware"][
                "value"
            ]["name"]

        return {
            "enabled": self.config.jupyterlite.enabled,
            "namespace": self.config.namespace,
            "external_url": external_url,
            "auth-enabled": self.config.jupyterlite.auth_enabled,
            "forwardauth-middleware-name": forwardauth_middleware_name,
            "overrides": json.dumps(self.config.jupyterlite.overrides),
        }


@hookimpl
def nebari_stage() -> list[NebariStage]:
    return [JupyterLiteStage]
