from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    database_url: str = "postgresql://cadenza:cadenza_dev@localhost:5432/cadenza"
    jwt_secret_key: str = "dev_secret_key_change_in_production"
    jwt_algorithm: str = "HS256"
    jwt_expiration_hours: int = 24 * 7

    class Config:
        env_file = ".env"

settings = Settings()
