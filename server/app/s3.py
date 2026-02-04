"""S3 service for handling file uploads and downloads."""

import os
from datetime import datetime, timedelta, timezone
from typing import Optional
from uuid import UUID

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from app.config import settings


def _get_path_prefix() -> str:
    """Get the S3 path prefix based on environment."""
    return "" if settings.is_production else f"{settings.environment}/"


def _get_object_tags() -> Optional[str]:
    """Get S3 object tags based on environment (30-day expiration for non-prod)."""
    if not settings.is_production:
        expiry_date = datetime.now(timezone.utc) + timedelta(days=30)
        return f"expiry-date={expiry_date.strftime('%Y-%m-%d')}"
    return None


def get_s3_client():
    """Get configured S3 client."""
    session_kwargs = {}
    aws_profile = os.getenv("AWS_PROFILE")  # For local development only
    if aws_profile:
        session_kwargs["profile_name"] = aws_profile

    session = boto3.Session(**session_kwargs)

    return session.client(
        "s3",
        region_name=settings.aws_region,
        config=Config(signature_version="s3v4"),
    )


def get_piece_s3_key(piece_id: UUID) -> str:
    """
    Generate S3 key for a piece.
    Format:
      - dev: dev/cadenza/pieces/{uuid}.pdf
      - prod: cadenza/pieces/{uuid}.pdf
    """
    return f"{_get_path_prefix()}cadenza/pieces/{piece_id}.pdf"


def get_video_s3_key(user_id: int, submission_id: UUID) -> str:
    return f"{_get_path_prefix()}cadenza/videos/{user_id}/{submission_id}.mp4"


def get_video_thumbnail_s3_key(user_id: int, submission_id: UUID) -> str:
    return f"{_get_path_prefix()}cadenza/videos/{user_id}/{submission_id}_thumb.jpg"


def upload_file_content(
    s3_key: str, content: bytes, content_type: str = "application/pdf"
) -> None:
    """
    Upload file content directly to S3.

    In dev environment, objects are tagged with a 30-day expiration.

    Args:
        s3_key: S3 key where file will be stored
        content: File content as bytes
        content_type: MIME type of the file (default: application/pdf)
    """
    s3_client = get_s3_client()

    try:
        put_params = {
            "Bucket": settings.s3_bucket,
            "Key": s3_key,
            "Body": content,
            "ContentType": content_type,
        }

        tags = _get_object_tags()
        if tags:
            put_params["Tagging"] = tags

        s3_client.put_object(**put_params)
    except ClientError as e:
        raise Exception(f"Failed to upload file to S3: {e}")


def generate_upload_url(piece_id: UUID, content_type: str = "application/pdf") -> dict:
    """
    Generate a presigned URL for uploading a PDF to S3.

    Args:
        piece_id: UUID of the piece
        content_type: MIME type of the file (default: application/pdf)

    Returns:
        dict with:
            - url: Presigned URL for PUT request
            - s3_key: The S3 key where file will be stored
            - expires_in: Seconds until URL expires
    """
    s3_client = get_s3_client()
    s3_key = get_piece_s3_key(piece_id)

    try:
        presigned_url = s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": s3_key,
                "ContentType": content_type,
            },
            ExpiresIn=3600,  # 1 hour
        )

        return {"url": presigned_url, "s3_key": s3_key, "expires_in": 3600}
    except ClientError as e:
        raise Exception(f"Failed to generate presigned URL: {e}")


def generate_video_upload_url(user_id: int, submission_id: UUID) -> dict:
    s3_client = get_s3_client()
    s3_key = get_video_s3_key(user_id, submission_id)

    try:
        presigned_url = s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": s3_key,
                "ContentType": "video/mp4",
            },
            ExpiresIn=3600,
        )

        return {"url": presigned_url, "s3_key": s3_key, "expires_in": 3600}
    except ClientError as e:
        raise Exception(f"Failed to generate presigned URL: {e}")


def generate_video_thumbnail_upload_url(user_id: int, submission_id: UUID) -> dict:
    s3_client = get_s3_client()
    s3_key = get_video_thumbnail_s3_key(user_id, submission_id)

    try:
        presigned_url = s3_client.generate_presigned_url(
            "put_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": s3_key,
                "ContentType": "image/jpeg",
            },
            ExpiresIn=3600,
        )

        return {"url": presigned_url, "s3_key": s3_key, "expires_in": 3600}
    except ClientError as e:
        raise Exception(f"Failed to generate presigned URL: {e}")


def generate_download_url(s3_key: str) -> str:
    """
    Generate a presigned URL for downloading a PDF from S3.

    Args:
        s3_key: S3 key of the file

    Returns:
        Presigned URL for GET request
    """
    s3_client = get_s3_client()

    try:
        presigned_url = s3_client.generate_presigned_url(
            "get_object",
            Params={
                "Bucket": settings.s3_bucket,
                "Key": s3_key,
            },
            ExpiresIn=3600,  # 1 hour
        )

        return presigned_url
    except ClientError as e:
        raise Exception(f"Failed to generate download URL: {e}")


def copy_bundled_to_user_piece(source_filename: str, piece_id: UUID) -> str:
    """
    Copy a bundled PDF to a user's piece location.

    Args:
        source_filename: Filename in infra/ios/bundle/
        piece_id: UUID of the new piece

    Returns:
        S3 key of the copied file
    """
    s3_client = get_s3_client()
    source_key = f"infra/ios/bundle/{source_filename}"
    dest_key = get_piece_s3_key(piece_id)

    try:
        copy_params = {
            "Bucket": settings.s3_bucket,
            "CopySource": {"Bucket": settings.s3_bucket, "Key": source_key},
            "Key": dest_key,
        }

        tags = _get_object_tags()
        if tags:
            copy_params["Tagging"] = tags
            copy_params["TaggingDirective"] = "REPLACE"

        s3_client.copy_object(**copy_params)

        return dest_key
    except ClientError as e:
        raise Exception(f"Failed to copy bundled file: {e}")


def delete_piece(s3_key: str) -> None:
    """
    Delete a piece from S3.

    Args:
        s3_key: S3 key of the file to delete
    """
    s3_client = get_s3_client()

    try:
        s3_client.delete_object(
            Bucket=settings.s3_bucket,
            Key=s3_key,
        )
    except ClientError as e:
        raise Exception(f"Failed to delete file from S3: {e}")
