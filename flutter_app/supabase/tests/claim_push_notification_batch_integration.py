import os
import threading
import time
import unittest
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import psycopg


PROJECT_ID = "11111111-1111-1111-1111-111111111111"
ALLOWED_KINDS = ["app_announcement"]
DATABASE_URL = os.environ.get(
    "TEST_DATABASE_URL",
    "postgresql://postgres:postgres@localhost:5432/postgres",
)


def migration_function_sql() -> str:
    migrations = Path(__file__).resolve().parents[1] / "migrations"
    matches = list(migrations.glob("*_harden_push_notification_worker.sql"))
    if len(matches) != 1:
        raise AssertionError(f"Expected one push hardening migration, found {matches}")
    source = matches[0].read_text(encoding="utf-8")
    start_marker = "create or replace function public.claim_push_notification_batch("
    start = source.index(start_marker)
    end_marker = "$function$;"
    end = source.index(end_marker, start) + len(end_marker)
    return source[start:end]


def connect():
    return psycopg.connect(DATABASE_URL, autocommit=False)


class ClaimPushNotificationBatchIntegrationTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        with connect() as connection:
            connection.execute("drop schema if exists public cascade")
            connection.execute("create schema public")
            connection.execute(
                """
                create table public.notification_outbox (
                  id bigint generated always as identity primary key,
                  project_id uuid not null,
                  kind text not null,
                  created_at timestamptz not null default now(),
                  delivery_status text not null default 'pending',
                  claim_id uuid,
                  claimed_at timestamptz,
                  attempt_count integer not null default 0,
                  last_attempt_at timestamptz,
                  next_attempt_at timestamptz,
                  last_error text
                )
                """
            )
            connection.execute(migration_function_sql())
            connection.commit()

    def setUp(self):
        with connect() as connection:
            connection.execute("truncate public.notification_outbox restart identity")
            connection.commit()

    def claim(self, connection, limit=20, lease_seconds=300, max_attempts=5):
        return connection.execute(
            """
            select id, delivery_status, claim_id, claimed_at, attempt_count,
                   last_attempt_at, next_attempt_at
            from public.claim_push_notification_batch(%s, %s, %s, %s, %s)
            order by id
            """,
            (PROJECT_ID, limit, lease_seconds, max_attempts, ALLOWED_KINDS),
        ).fetchall()

    def insert_pending(self, count):
        with connect() as connection:
            connection.execute(
                """
                insert into public.notification_outbox(project_id, kind, created_at)
                select %s, 'app_announcement', now() + make_interval(secs => value)
                from generate_series(1, %s) as value
                """,
                (PROJECT_ID, count),
            )
            connection.commit()

    def test_two_independent_sessions_claim_disjoint_batches(self):
        self.insert_pending(40)
        start = threading.Barrier(2)
        claimed = threading.Barrier(2)

        def worker():
            with connect() as connection:
                connection.execute("set local lock_timeout = '2s'")
                connection.execute("set local statement_timeout = '5s'")
                start.wait(timeout=5)
                rows = self.claim(connection)
                # Keep the transaction and its row locks open until the other
                # independent session has completed its claim.
                claimed.wait(timeout=5)
                connection.commit()
                return rows

        started_at = time.monotonic()
        with ThreadPoolExecutor(max_workers=2) as executor:
            first_future = executor.submit(worker)
            second_future = executor.submit(worker)
            first = first_future.result(timeout=10)
            second = second_future.result(timeout=10)

        self.assertLess(time.monotonic() - started_at, 5)
        first_ids = {row[0] for row in first}
        second_ids = {row[0] for row in second}
        self.assertEqual(len(first_ids), 20)
        self.assertEqual(len(second_ids), 20)
        self.assertTrue(first_ids.isdisjoint(second_ids))
        self.assertEqual(first_ids | second_ids, set(range(1, 41)))

        with connect() as connection:
            rows = connection.execute(
                """
                select id, delivery_status, claim_id, attempt_count
                from public.notification_outbox
                order by id
                """
            ).fetchall()
        self.assertEqual(len(rows), 40)
        self.assertTrue(all(row[1] == "processing" for row in rows))
        self.assertTrue(all(row[2] is not None for row in rows))
        self.assertTrue(all(row[3] == 1 for row in rows))
        self.assertEqual(len({row[2] for row in rows}), 40)

    def test_active_lease_is_not_reclaimed(self):
        with connect() as connection:
            connection.execute(
                """
                insert into public.notification_outbox(
                  project_id, kind, delivery_status, claim_id, claimed_at,
                  attempt_count, last_attempt_at
                ) values (%s, 'app_announcement', 'processing', gen_random_uuid(),
                          now(), 1, now())
                """,
                (PROJECT_ID,),
            )
            connection.commit()
        with connect() as connection:
            self.assertEqual(self.claim(connection), [])
            connection.commit()

    def test_expired_lease_is_reclaimed_with_new_claim(self):
        with connect() as connection:
            original = connection.execute(
                """
                insert into public.notification_outbox(
                  project_id, kind, delivery_status, claim_id, claimed_at,
                  attempt_count, last_attempt_at
                ) values (%s, 'app_announcement', 'processing', gen_random_uuid(),
                          now() - interval '301 seconds', 1,
                          now() - interval '301 seconds')
                returning id, claim_id
                """,
                (PROJECT_ID,),
            ).fetchone()
            connection.commit()
        with connect() as connection:
            reclaimed = self.claim(connection)
            connection.commit()
        self.assertEqual(len(reclaimed), 1)
        self.assertEqual(reclaimed[0][0], original[0])
        self.assertEqual(reclaimed[0][1], "processing")
        self.assertIsNotNone(reclaimed[0][2])
        self.assertNotEqual(reclaimed[0][2], original[1])
        self.assertEqual(reclaimed[0][4], 2)

    def test_expired_lease_at_max_attempts_becomes_failed(self):
        with connect() as connection:
            row_id = connection.execute(
                """
                insert into public.notification_outbox(
                  project_id, kind, delivery_status, claim_id, claimed_at,
                  attempt_count, last_attempt_at
                ) values (%s, 'app_announcement', 'processing', gen_random_uuid(),
                          now() - interval '301 seconds', 5,
                          now() - interval '301 seconds')
                returning id
                """,
                (PROJECT_ID,),
            ).fetchone()[0]
            connection.commit()
        with connect() as connection:
            self.assertEqual(self.claim(connection), [])
            state = connection.execute(
                """
                select delivery_status, claim_id, claimed_at, attempt_count,
                       next_attempt_at, last_error
                from public.notification_outbox where id = %s
                """,
                (row_id,),
            ).fetchone()
            connection.commit()
        self.assertEqual(state[0], "failed")
        self.assertIsNone(state[1])
        self.assertIsNone(state[2])
        self.assertEqual(state[3], 5)
        self.assertIsNone(state[4])
        self.assertIsNotNone(state[5])

    def test_next_attempt_at_delays_claim(self):
        with connect() as connection:
            row_id = connection.execute(
                """
                insert into public.notification_outbox(
                  project_id, kind, delivery_status, next_attempt_at
                ) values (%s, 'app_announcement', 'pending', now() + interval '1 hour')
                returning id
                """,
                (PROJECT_ID,),
            ).fetchone()[0]
            connection.commit()
        with connect() as connection:
            self.assertEqual(self.claim(connection), [])
            state = connection.execute(
                "select delivery_status, attempt_count from public.notification_outbox where id = %s",
                (row_id,),
            ).fetchone()
            self.assertEqual(state, ("pending", 0))
            connection.execute(
                "update public.notification_outbox set next_attempt_at = now() - interval '1 second' where id = %s",
                (row_id,),
            )
            reclaimed = self.claim(connection)
            connection.commit()
        self.assertEqual(len(reclaimed), 1)
        self.assertEqual(reclaimed[0][0], row_id)
        self.assertEqual(reclaimed[0][1], "processing")
        self.assertIsNotNone(reclaimed[0][2])
        self.assertEqual(reclaimed[0][4], 1)
        self.assertIsNone(reclaimed[0][6])


if __name__ == "__main__":
    unittest.main(verbosity=2)
