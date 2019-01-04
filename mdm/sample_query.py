#!/usr/bin/env python
import snowflake.connector
from getpass import getpass

USER = input("enter snowflake username: ")
PASS = getpass("enter snowflake password: ")
ACCOUNT = getpass("enter snowflake account: ")

# Connect to Snoflake
con = snowflake.connector.connect(
    user = USER,
    password = PASS,
    account = ACCOUNT
)

# create cursor for querying
cur = con.cursor()

# attempt query statement
try:
    con.cursor().execute("USE warehouse COMPUTE_WH")
    con.cursor().execute("USE GIANTS_POC_DB.MINI_PACK")
    cur.execute("SELECT financial_patron_account_id, first_name, last_name FROM mini_pack_individual_dim LIMIT 10")

    for (financial_patron_account_id, first_name, last_name) in cur:
        print(f'{financial_patron_account_id}, {first_name}, {last_name}')

finally:
    cur.close()
con.close()