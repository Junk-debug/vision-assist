import os
import tempfile
import unittest

from frame_server import Sequence, expand_paths, pan_windows


class SequenceTest(unittest.TestCase):
    def test_single_image_never_changes(self):
        sequence = Sequence(["a.jpg"], fps=10, loop=True, started_at=0)
        self.assertEqual(sequence.index_at(100), 0)

    def test_loops_at_the_given_rate(self):
        sequence = Sequence(["a", "b", "c"], fps=2, loop=True, started_at=10)
        self.assertEqual([sequence.index_at(10 + t / 2) for t in range(7)], [0, 1, 2, 0, 1, 2, 0])

    def test_stops_on_the_last_frame_without_loop(self):
        sequence = Sequence(["a", "b", "c"], fps=1, loop=False, started_at=0)
        self.assertEqual(sequence.index_at(1.5), 1)
        self.assertEqual(sequence.index_at(50), 2)

    def test_clock_before_start_shows_the_first_frame(self):
        sequence = Sequence(["a", "b"], fps=1, loop=True, started_at=5)
        self.assertEqual(sequence.index_at(1), 0)

    def test_rejects_empty_or_still_sequences(self):
        with self.assertRaises(ValueError):
            Sequence([])
        with self.assertRaises(ValueError):
            Sequence(["a"], fps=0)


class PathsTest(unittest.TestCase):
    def test_folders_expand_to_sorted_images(self):
        with tempfile.TemporaryDirectory() as folder:
            for name in ["b.png", "a.jpg", "notes.txt"]:
                open(os.path.join(folder, name), "wb").close()
            files = expand_paths([folder])
            self.assertEqual([os.path.basename(f) for f in files], ["a.jpg", "b.png"])

    def test_missing_files_are_reported(self):
        with self.assertRaises(ValueError):
            expand_paths(["/does/not/exist.jpg"])


class PanTest(unittest.TestCase):
    def centre_share(self, window, width, height):
        left, top, crop_w, crop_h = window
        return (width / 2 - left) / crop_w, (height / 2 - top) / crop_h

    def test_object_moves_from_the_left_edge_to_the_centre(self):
        windows = pan_windows(1000, 800, 5, "left", 0.5, 0.5)
        first_x, _ = self.centre_share(windows[0], 1000, 800)
        last_x, last_y = self.centre_share(windows[-1], 1000, 800)
        self.assertAlmostEqual(first_x, 0.1, places=2)
        self.assertAlmostEqual(last_x, 0.5, places=2)
        self.assertAlmostEqual(last_y, 0.5, places=2)
        shares = [self.centre_share(w, 1000, 800)[0] for w in windows]
        self.assertEqual(shares, sorted(shares))

    def test_windows_stay_inside_the_image(self):
        for start in ["left", "right", "top", "bottom"]:
            for left, top, crop_w, crop_h in pan_windows(640, 480, 8, start, 0.8, 0.3):
                self.assertGreaterEqual(left, 0)
                self.assertGreaterEqual(top, 0)
                self.assertLessEqual(left + crop_w, 640)
                self.assertLessEqual(top + crop_h, 480)

    def test_end_zoom_makes_the_object_larger(self):
        windows = pan_windows(1000, 1000, 3, "right", 0.6, 0.3)
        self.assertGreater(windows[0][2], windows[-1][2])


if __name__ == "__main__":
    unittest.main()
