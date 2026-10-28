"""Regression tests for true PNG bytes versus JPEG attachments named .png."""
import hashlib
import tempfile
import unittest
from pathlib import Path

from PIL import Image

from verify_master_source import inspect_file


class TestSourceIdentity(unittest.TestCase):
    def test_exact_png_blob_identity(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "master-male-09-approved.png"
            Image.new("RGB", (1198,1313), (210,160,100)).save(file, "PNG")
            raw = file.read_bytes()
            sha1 = hashlib.sha1(
                b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
            ).hexdigest()
            report = inspect_file(file, expected_blob=sha1)
            self.assertEqual(report["detected_format"], "PNG")
            self.assertTrue(report["geometry_matches_p1"])
            self.assertTrue(report["png_signature"])
            self.assertTrue(report["exact_git_source_match"])
            self.assertEqual(report["usage"], "git_master")

    def test_jpeg_named_png_is_rejected_even_with_matched_blob(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "master-male-09-approved.png"
            Image.new("RGB", (1198,1313), (210,160,100)).save(file, "JPEG")
            raw = file.read_bytes()
            sha1 = hashlib.sha1(
                b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
            ).hexdigest()
            report = inspect_file(file, expected_blob=sha1)
            self.assertEqual(report["detected_format"], "JPEG")
            self.assertFalse(report["png_signature"])
            self.assertFalse(report["exact_git_source_match"])
            self.assertEqual(report["usage"], "visual_reference_only")

    def test_wrong_geometry_is_rejected_even_for_png(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "test.png"
            Image.new("RGB", (1229,1536), (210,160,100)).save(file, "PNG")
            raw = file.read_bytes()
            sha1 = hashlib.sha1(
                b"blob " + str(len(raw)).encode("ascii") + b"\0" + raw
            ).hexdigest()
            report = inspect_file(file, expected_blob=sha1)
            self.assertFalse(report["geometry_matches_p1"])
            self.assertFalse(report["exact_git_source_match"])

    def test_wrong_git_sha_rejected_with_same_raster(self):
        with tempfile.TemporaryDirectory() as folder:
            file = Path(folder) / "test.png"
            Image.new("RGB", (1198,1313), (210,160,100)).save(file, "PNG")
            report = inspect_file(file, expected_blob="0" * 40)
            self.assertTrue(report["geometry_matches_p1"])
            self.assertFalse(report["exact_git_source_match"])


if __name__ == "__main__":
    unittest.main()
