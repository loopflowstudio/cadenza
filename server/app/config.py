from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")

    # Environment: "dev", "staging", or "prod"
    environment: str = "dev"

    # Database
    database_url: str = "postgresql://cadenza:cadenza_dev@localhost:5432/cadenza"

    # Auth
    jwt_secret_key: str = "dev_secret_key_change_in_production"
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 24 * 7

    # S3
    s3_bucket: str = "loopflow"
    aws_region: str = "us-west-2"

    @property
    def is_production(self) -> bool:
        return self.environment == "prod"


settings = Settings()
