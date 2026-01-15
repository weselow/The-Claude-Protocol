"""Codex API client for invoking agents."""

import asyncio
import json
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

# Map agent model preferences to Codex models
MODEL_MAPPING = {
    "haiku": "gpt-5.1-codex-mini",    # Scout, Scribe, Code-Reviewer - cheaper, faster
    "sonnet": "gpt-5.2-codex",        # Discovery - latest frontier
    "opus": "gpt-5.1-codex-max",      # Detective, Architect - deep reasoning
}


class CodexClient:
    """Client for invoking Codex with agent prompts."""

    def __init__(self, model: str = "gpt-5.2-codex"):
        """
        Initialize Codex client.

        Args:
            model: Codex model to use (default: gpt-5.2-codex)
        """
        self.model = model

    @staticmethod
    def map_model(agent_model: str) -> str:
        """Map agent's preferred model to Codex model."""
        return MODEL_MAPPING.get(agent_model, "gpt-5.2-codex")

    async def invoke(
        self,
        system_prompt: str,
        user_prompt: str,
        task_id: Optional[str] = None,
    ) -> str:
        """
        Invoke Codex with agent system prompt and user task.

        Args:
            system_prompt: Agent's system prompt (from .md file)
            user_prompt: User's task description
            task_id: Optional Kanban task ID for context

        Returns:
            Codex response text

        Raises:
            RuntimeError: If Codex invocation fails
        """
        # Construct combined prompt (Codex doesn't have separate system prompt parameter)
        # Combine agent identity/instructions with user task
        combined_prompt = f"{system_prompt}\n\n---\n\n{user_prompt}"

        if task_id:
            combined_prompt = f"TASK_ID: {task_id}\n\n{combined_prompt}"

        # Invoke Codex via CLI
        # Format: codex exec -m <model> --sandbox workspace-write <prompt>
        cmd = [
            "codex",
            "exec",
            "-m", self.model,
            "--sandbox", "workspace-write",  # Required sandbox parameter
            combined_prompt,
        ]

        logger.info(f"Invoking Codex with model: {self.model}")
        logger.debug(f"System prompt length: {len(system_prompt)} chars")
        logger.debug(f"Combined prompt: {combined_prompt[:200]}...")

        try:
            # Get current working directory
            cwd = os.getcwd()

            # Inherit environment variables from parent process
            # This allows Codex to find MCP configuration and start MCP servers
            env = os.environ.copy()

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=env,  # Pass environment variables
                cwd=cwd,  # Set working directory
            )

            stdout, stderr = await process.communicate()

            if process.returncode != 0:
                error_msg = stderr.decode() if stderr else "Unknown error"
                raise RuntimeError(f"Codex invocation failed: {error_msg}")

            response = stdout.decode().strip()
            logger.info(f"Codex response length: {len(response)} chars")

            return response

        except FileNotFoundError:
            raise RuntimeError(
                "Codex CLI not found. Install and authenticate with: codex login"
            )
        except Exception as e:
            logger.error(f"Codex invocation error: {e}")
            raise RuntimeError(f"Failed to invoke Codex: {e}")
