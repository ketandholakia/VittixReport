"""Offline release regression tests; pass a DB built from the pinned SQL helper."""
import argparse
from contextlib import closing
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from verify_northwind import verify_northwind

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--database', type=Path, required=True)
args = parser.parse_args()


class NorthwindPayloadTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'northwind.db'
        self.path.write_bytes(args.database.read_bytes())

    def test_pinned_generated_sample(self):
        verify_northwind(self.path)

    def test_only_writer_version_may_differ(self):
        data = bytearray(self.path.read_bytes())
        data[96:100] = (3050004).to_bytes(4, 'big')
        self.path.write_bytes(data)
        verify_northwind(self.path)

    def test_changed_value_with_same_row_count_is_rejected(self):
        with closing(sqlite3.connect(self.path)) as db, db:
            count = db.execute('SELECT COUNT(*) FROM Customers').fetchone()[0]
            db.execute("UPDATE Customers SET CompanyName = 'payload tamper' WHERE CustomerID = (SELECT MIN(CustomerID) FROM Customers)")
            self.assertEqual(db.execute('SELECT COUNT(*) FROM Customers').fetchone()[0], count)
        self.assertRaises(ValueError, verify_northwind, self.path)

    def test_added_schema_is_rejected(self):
        with closing(sqlite3.connect(self.path)) as db, db:
            db.execute('CREATE TABLE unexpected (value TEXT)')
        self.assertRaises(ValueError, verify_northwind, self.path)

    def test_other_header_changes_are_rejected(self):
        data = bytearray(self.path.read_bytes())
        data[60] ^= 1
        self.path.write_bytes(data)
        self.assertRaises(ValueError, verify_northwind, self.path)

    def test_appended_bytes_are_rejected(self):
        with self.path.open('ab') as stream:
            stream.write(b'unexpected payload')
        self.assertRaises(ValueError, verify_northwind, self.path)

    def test_truncated_file_is_rejected(self):
        self.path.write_bytes(self.path.read_bytes()[:96])
        self.assertRaises(ValueError, verify_northwind, self.path)


if __name__ == '__main__':
    unittest.main(argv=[sys.argv[0]], verbosity=2)
