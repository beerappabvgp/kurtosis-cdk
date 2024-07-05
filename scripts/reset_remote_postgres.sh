#!/bin/bash

DB_NAMES=("event_db" "pool_db" "prover_db" "state_db" "agglayer_db" "bridge_db" "dac_db")
DB_USERS=("event_user" "pool_user" "prover_user" "state_user" "agglayer_user" "bridge_user" "dac_user")

PGPASSWORD='postgres'
HOST='your_server_ip'
PORT=5432

for i in "${!DB_NAMES[@]}"; do
    DB_NAME="${DB_NAMES[$i]}"
    DB_USER="${DB_USERS[$i]}"

    echo "Resetting database: $DB_NAME"

    # initially connect as master postgres user to drop/recreate dbs
    PGPASSWORD=$PGPASSWORD psql -h $HOST -p $PORT -U postgres <<EOF
    DROP DATABASE IF EXISTS $DB_NAME;
    CREATE DATABASE $DB_NAME;
    GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;   
EOF

    # connect to specific database for db initialization
    PGPASSWORD=$PGPASSWORD psql -h $HOST -p $PORT -U postgres -d $DB_NAME <<EOF
    CREATE SCHEMA IF NOT EXISTS public;
    GRANT USAGE ON SCHEMA public TO $DB_USER;
    GRANT CREATE ON SCHEMA public TO $DB_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $DB_USER;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO $DB_USER;
    GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO $DB_USER;
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;  
EOF
    echo "Database $DB_NAME has been reset and permissions granted to $DB_USER."

    if [ "$DB_NAME" == "event_db" ]; then
        echo "Setting up public.event table for $DB_NAME"
        PGPASSWORD=$PGPASSWORD psql -h $HOST -p $PORT -U postgres -d $DB_NAME <<EOF
        CREATE TYPE IF NOT EXISTS level_t AS ENUM ('emerg', 'alert', 'crit', 'err', 'warning', 'notice', 'info', 'debug');

        CREATE TABLE IF NOT EXISTS public.event (
           id BIGSERIAL PRIMARY KEY,
           received_at timestamp WITH TIME ZONE default CURRENT_TIMESTAMP,
           ip_address inet,
           source varchar(32) not null,
           component varchar(32),
           level level_t not null,
           event_id varchar(32) not null,
           description text,
           data bytea,
           json jsonb
        );
EOF
    fi

    if [ "$DB_NAME" == "prover_db" ]; then
        echo "Setting up schema state for $DB_NAME"
        PGPASSWORD=$PGPASSWORD psql -h $HOST -p $PORT -U postgres -d $DB_NAME <<EOF
        CREATE SCHEMA IF NOT EXISTS state;
        GRANT USAGE ON SCHEMA state TO $DB_USER;
        GRANT CREATE ON SCHEMA state TO $DB_USER;
        ALTER DEFAULT PRIVILEGES IN SCHEMA state GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO $DB_USER;
        ALTER DEFAULT PRIVILEGES IN SCHEMA state GRANT EXECUTE ON FUNCTIONS TO $DB_USER;
        GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA state TO $DB_USER;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA state TO $DB_USER;

        CREATE TABLE IF NOT EXISTS state.nodes (
           hash BYTEA PRIMARY KEY,
           data BYTEA NOT NULL
        );

        CREATE TABLE IF NOT EXISTS state.program (
           hash BYTEA PRIMARY KEY,
           data BYTEA NOT NULL
        );
EOF
    fi
done
