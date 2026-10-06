"""Factory model selection; existing callers retain Anthropic unless explicitly configured."""
from app.config import Settings
from app.llm.client import AnthropicClient
from app.llm.models import model_policy
from app.llm.openai_client import OpenAIClient


def factory_client(settings: Settings) -> AnthropicClient | OpenAIClient:
    selected = settings.factory_llm_model
    if selected is not None:
        policy = model_policy(selected, settings)
        if policy.provider == "openai":
            return OpenAIClient(settings, model=selected)
        settings = settings.model_copy(update={"llm_model_strong": selected, "llm_model_fast": selected})
    return AnthropicClient(settings)
