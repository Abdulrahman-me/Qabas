"""S3Storage request shapes, checked with botocore's Stubber (no network)."""

from __future__ import annotations

import io

import boto3
import pytest
from botocore.response import StreamingBody
from botocore.stub import Stubber

from app.services.platform.storage import Bucket, ImmutableObjectError, S3Storage, sha256_hex


@pytest.fixture
def s3() -> tuple[S3Storage, Stubber]:
    client = boto3.client("s3", region_name="auto", endpoint_url="https://s3.example.test",
                          aws_access_key_id="test", aws_secret_access_key="test")
    stubber = Stubber(client)
    stubber.activate()
    return S3Storage(client, content_bucket="content", private_bucket="private",
                     cdn_base_url="https://cdn.example.test"), stubber


def test_content_put_is_immutable(s3: tuple[S3Storage, Stubber]) -> None:
    storage, stub = s3
    data = b"manifest"
    stub.add_client_error("head_object", "404", expected_params={"Bucket": "content", "Key": "scenes/a.json"})
    stub.add_response("put_object", {}, {"Bucket": "content", "Key": "scenes/a.json", "Body": data,
                                         "ContentType": "application/json",
                                         "CacheControl": "public, max-age=31536000, immutable",
                                         "Metadata": {"sha256": sha256_hex(data)}})
    assert storage.put(Bucket.content, "scenes/a.json", data, "application/json").sha256 == sha256_hex(data)
    stub.add_response("head_object", {"Metadata": {"sha256": sha256_hex(data)}, "ContentType": "application/json"},
                      {"Bucket": "content", "Key": "scenes/a.json"})
    storage.put(Bucket.content, "scenes/a.json", data, "application/json")  # identical: no write
    stub.add_response("head_object", {"Metadata": {"sha256": sha256_hex(data)}},
                      {"Bucket": "content", "Key": "scenes/a.json"})
    with pytest.raises(ImmutableObjectError):
        storage.put(Bucket.content, "scenes/a.json", b"changed", "application/json")
    stub.assert_no_pending_responses()


def test_private_prefix_purge_and_reads(s3: tuple[S3Storage, Stubber]) -> None:
    storage, stub = s3
    stub.add_response("list_objects_v2", {"Contents": [{"Key": "users/usr_x/a"}, {"Key": "users/usr_x/b"}],
                                          "IsTruncated": False},
                      {"Bucket": "private", "Prefix": "users/usr_x/"})
    stub.add_response("delete_objects", {}, {"Bucket": "private", "Delete": {
        "Objects": [{"Key": "users/usr_x/a"}, {"Key": "users/usr_x/b"}], "Quiet": True}})
    assert storage.delete_private_prefix("users/usr_x/") == 2
    stub.add_response("get_object", {"Body": StreamingBody(io.BytesIO(b"x"), 1)},
                      {"Bucket": "private", "Key": "users/usr_x/a"})
    assert storage.get(Bucket.private, "users/usr_x/a") == b"x"
    stub.assert_no_pending_responses()


def test_urls(s3: tuple[S3Storage, Stubber]) -> None:
    storage, _ = s3
    assert storage.public_url("img/a b.webp") == "https://cdn.example.test/img/a%20b.webp"
    signed = storage.signed_url("users/usr_x/a", 900)
    assert "/private/users/usr_x/a?" in signed
    assert "Signature=" in signed or "X-Amz-Signature=" in signed
