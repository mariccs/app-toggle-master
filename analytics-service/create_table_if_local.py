import os
import sys
import time
import boto3
from botocore.config import Config
from botocore.exceptions import ClientError, EndpointConnectionError, ConnectTimeoutError

AWS_REGION = os.getenv("AWS_REGION", "us-east-1")
TABLE_NAME = os.getenv("AWS_DYNAMODB_TABLE", "ToggleMasterAnalytics")
ENDPOINT_URL = os.getenv("AWS_DYNAMODB_ENDPOINT_URL")

if not ENDPOINT_URL:
    sys.exit(0)

boto_config = Config(connect_timeout=2, read_timeout=2,
                     retries={"max_attempts": 1})
client = boto3.client(
    "dynamodb", region_name=AWS_REGION, endpoint_url=ENDPOINT_URL, config=boto_config
)

MAX_ATTEMPTS = 30
SLEEP_SECONDS = 2

for attempt in range(1, MAX_ATTEMPTS + 1):
    try:
        client.create_table(
            TableName=TABLE_NAME,
            AttributeDefinitions=[
                {"AttributeName": "event_id", "AttributeType": "S"}],
            KeySchema=[{"AttributeName": "event_id", "KeyType": "HASH"}],
            BillingMode="PAY_PER_REQUEST",
        )
        print(
            f"[create_table_if_local] Tabela '{TABLE_NAME}' criada no DynamoDB Local.")
        break
    except ClientError as e:
        if e.response["Error"]["Code"] == "ResourceInUseException":
            print(
                f"[create_table_if_local] Tabela '{TABLE_NAME}' já existe. Ok.")
            break
        print(f"[create_table_if_local] Erro ao criar tabela: {e}")
        break
    except (EndpointConnectionError, ConnectTimeoutError, Exception) as e:
        print(
            f"[create_table_if_local] Tentativa {attempt}/{MAX_ATTEMPTS}: "
            f"DynamoDB Local ainda não respondeu em {ENDPOINT_URL} ({e}). "
            f"Aguardando {SLEEP_SECONDS}s..."
        )
        time.sleep(SLEEP_SECONDS)
else:
    print(
        f"[create_table_if_local] Desisti após {MAX_ATTEMPTS} tentativas. "
        "Seguindo em frente mesmo assim — o worker tentará gravar em runtime."
    )
