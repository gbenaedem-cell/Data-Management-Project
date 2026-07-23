import os

from dotenv import load_dotenv
from sqlalchemy import create_engine, text
from sqlalchemy.engine import URL

load_dotenv()

connection_url = URL.create(
    drivername="mysql+pymysql",
    username=os.getenv("MYSQL_USER"),
    password=os.getenv("MYSQL_PASSWORD"),
    host=os.getenv("MYSQL_HOST"),
    port=int(os.getenv("MYSQL_PORT", "3306")),
    database=os.getenv("MYSQL_DATABASE"),
)

engine = create_engine(connection_url)

with engine.connect() as connection:
    result = connection.execute(
        text("SELECT DATABASE() AS database_name, VERSION() AS mysql_version")
    ).one()

    print(f"Connected to database: {result.database_name}")
    print(f"MySQL version: {result.mysql_version}")