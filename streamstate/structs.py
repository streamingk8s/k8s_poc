from dataclasses import dataclass, field
import marshmallow_dataclass
import marshmallow.validate
from marshmallow import Schema
from typing import ClassVar, Type


@dataclass
class OutputStruct:
    mode: str
    checkpoint_location: str
    output_name: str
    processing_time: str = "0"
    Schema: ClassVar[Type[Schema]] = Schema  # for mypy


@dataclass
class FileStruct:
    max_file_age: str
    Schema: ClassVar[Type[Schema]] = Schema  # for mypy


@dataclass
class CassandraStruct:
    cassandra_cluster: str
    cassandra_ip: str
    cassandra_port: str
    cassandra_key_space: str
    cassandra_table_name: str
    cassandra_password: str
    cassandra_user: str
    Schema: ClassVar[Type[Schema]] = Schema  # for mypy


@dataclass
class KafkaStruct:
    brokers: str
    Schema: ClassVar[Type[Schema]] = Schema  # for mypy