"""Unit tests on synthetic masks only; these are not full-image visual tests."""
import unittest
import numpy as np

import p1_mask_edits as work


class TestMaskEdits(unittest.TestCase):
    def setUp(self):
        self.size = (40, 30)
        self.zero = {x: np.zeros((30, 40), np.float32) for x in work.CATEGORIES}
        self.doc = dict(schema_version=1, source_size=[40,30], operations=[])

    def test_no_changes_when_empty(self):
        result = work.apply_edits(self.zero, self.doc, self.size)
        self.assertTrue(all(np.array_equal(result[k], self.zero[k]) for k in work.CATEGORIES))

    def test_include_and_exclude_with_protected_other_masks(self):
        self.doc['operations'] = [
            dict(mask='skin', action='include', shape='polygon',
                 points=[[8,5],[20,5],[20,22],[8,22]], feather=0),
            dict(mask='skin', action='exclude', shape='brush',
                 points=[[10,10]], radius=2, feather=0),
        ]
        result = work.apply_edits(self.zero, self.doc, self.size)
        self.assertEqual(result['skin'][15,15], 1)
        self.assertEqual(result['skin'][10,10], 0)
        self.assertEqual(result['skin'][0,0], 0)
        self.assertEqual(result['hair'].max(), 0)

    def test_reject_out_of_bounds_and_wrong_size(self):
        self.doc['operations'] = [
            dict(mask='skin', action='include', shape='polygon',
                 points=[[8,5],[45,5],[20,22]], feather=0)]
        with self.assertRaises(ValueError):
            work.apply_edits(self.zero, self.doc, self.size)
        self.doc['source_size'] = [1229,1536]
        with self.assertRaises(ValueError):
            work.apply_edits(self.zero, self.doc, self.size)

    def test_hair_groups_reassemble_original(self):
        hair = np.random.default_rng(12).uniform(0, 1, size=(700,1000)).astype(np.float32)
        cap, face = work.hair_groups(hair)
        self.assertTrue(np.allclose(cap + face, hair))
        self.assertEqual(face[400,300], 0)
        self.assertGreater(face[290,480], 0)


if __name__ == '__main__':
    unittest.main()
