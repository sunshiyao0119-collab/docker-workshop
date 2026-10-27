#!/usr/bin/env python
# coding: utf-8
"""读取出租车地区对照 CSV，并导入 PostgreSQL。"""

import click
import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy.engine import URL


dtype = {
    "LocationID": "Int64",
    "Borough": "string",
    "Zone": "string",
    "service_zone": "string",
}


@click.command()
@click.option('--pg-user', default='root', help='PostgreSQL username')
@click.option('--pg-pass', default='root', help='PostgreSQL password')
@click.option('--pg-host', default='localhost', help='PostgreSQL host')
@click.option('--pg-port', default=5432, type=int, help='PostgreSQL port')
@click.option('--pg-db', default='ny_taxi', help='PostgreSQL database name')
@click.option('--target-table', default='zones', help='Target table name')
@click.option(
    '--url',
    default='https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv',
    help='Taxi zone lookup CSV URL or local CSV path',
)
@click.option(
    '--if-exists',
    default='fail',
    type=click.Choice(['fail', 'replace']),
    help='fail: stop if the table exists; replace: overwrite the table',
)
def run(pg_user, pg_pass, pg_host, pg_port, pg_db, target_table, url, if_exists):
    # 地区表很小，一次读取即可，不需要按年月或分批导入。
    click.echo('正在读取地区对照 CSV……')
    df_zones = pd.read_csv(url, dtype=dtype)
    click.echo(f'读取完成，共 {len(df_zones)} 行。')

    # URL.create 会正确处理密码中可能包含的 @、: 等特殊字符。
    database_url = URL.create(
        drivername='postgresql+psycopg2',
        username=pg_user,
        password=pg_pass,
        host=pg_host,
        port=pg_port,
        database=pg_db,
    )
    engine = create_engine(database_url, connect_args={'connect_timeout': 5})

    try:
        # 正常完成后提交；发生错误则回滚本次事务。
        with engine.begin() as conn:
            df_zones.to_sql(
                name=target_table,
                con=conn,
                if_exists=if_exists,
                index=False,
            )
    finally:
        engine.dispose()

    click.echo(f'导入完成：{target_table}，共 {len(df_zones)} 行。')


if __name__ == '__main__':
    run()
