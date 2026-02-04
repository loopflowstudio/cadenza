from pydantic import model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

DEFAULT_DATABASE_URL = "postgresql://cadenza:cadenza_dev@localhost:5432/cadenza"
DEFAULT_JWT_SECRET_KEY = "dev_secret_key_change_in_production"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Environment: "dev", "staging", or "prod"
    environment: str = "dev"

    # Database
    database_url: str = DEFAULT_DATABASE_URL

    # Auth
    jwt_secret_key: str = DEFAULT_JWT_SECRET_KEY
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 24 * 7
    apple_client_id: str = "com.loopflow.cadenza"

    # CORS
    cors_origins: str = "http://localhost:3000"

    # Rate limiting
    rate_limit_auth: str = "10/minute"
    rate_limit_write: str = "30/minute"
    rate_limit_read: str = "100/minute"

    # S3
    s3_bucket: str = "loopflow"
    aws_region: str = "us-west-2"

    @property
    def is_dev(self) -> bool:
        return self.environment == "dev"

    @property
    def is_production(self) -> bool:
        return self.environment == "prod"

    @property
    def cors_origins_list(self) -> list[str]:
        if self.is_dev:
            return ["*"]
        return [origin.strip() for origin in self.cors_origins.split(",") if origin]

    @model_validator(mode="after")
    def validate_non_dev_settings(self) -> "Settings":
        if not self.is_dev:
            if self.database_url == DEFAULT_DATABASE_URL:
                raise ValueError("DATABASE_URL must be set in non-dev environments")
            if self.jwt_secret_key == DEFAULT_JWT_SECRET_KEY:
                raise ValueError("JWT_SECRET_KEY must be set in non-dev environments")
        return self


settings = Settings()
