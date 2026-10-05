"""FastAPI application factory."""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import (
    admin_factory,
    admin_review,
    auth,
    community,
    health,
    journey,
    learning_profile,
    me,
    media,
    raqeeb,
    recitation,
    sessions,
)
from app.config import Settings, StorageBackend, get_settings
from app.errors import install_error_handlers
from app.logs import configure_logging
from app.middleware import ContractIdentityMiddleware, RequestContextMiddleware
from app.openapi import install_openapi
from app.runtime import lifespan

API_PREFIX = "/v1"


def create_app(settings: Settings | None = None) -> FastAPI:
    settings = settings or get_settings()
    configure_logging(settings.log_level)
    app = FastAPI(
        title="Qabas API",
        version=f"contract-{settings.contract_revision}",
        description="Qabas public API (contract revision 10).",
        docs_url="/docs" if settings.is_dev_like else None,
        redoc_url=None,
        openapi_url="/openapi.json",
        lifespan=lifespan,
    )
    app.state.settings = settings
    install_error_handlers(app)
    install_openapi(app)

    # Starlette runs the last-added middleware first: CORS -> request context -> contract identity.
    app.add_middleware(ContractIdentityMiddleware, settings=settings)
    app.add_middleware(RequestContextMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_allowed_origins,
        allow_credentials=False,  # bearer headers only, never cookies
        allow_methods=["GET", "POST", "PATCH", "DELETE"],
        allow_headers=["Authorization", "Content-Type", "Accept-Language", "Qabas-Contract",
                       "Qabas-Client", "Idempotency-Key"],
        expose_headers=["Qabas-Contract"],
    )

    app.include_router(health.router)
    app.include_router(auth.router, prefix=API_PREFIX)
    app.include_router(me.router, prefix=API_PREFIX)
    app.include_router(journey.router, prefix=API_PREFIX)
    app.include_router(sessions.router, prefix=API_PREFIX)
    app.include_router(learning_profile.router, prefix=API_PREFIX)
    app.include_router(recitation.router, prefix=API_PREFIX)
    app.include_router(raqeeb.router, prefix=API_PREFIX)
    app.include_router(community.router, prefix=API_PREFIX)
    app.include_router(admin_factory.router, prefix=API_PREFIX)
    app.include_router(admin_review.router, prefix=API_PREFIX)
    if settings.storage_backend is StorageBackend.local:
        app.include_router(media.router)
    return app


app = create_app()
