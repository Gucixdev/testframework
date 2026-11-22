import sys, pathlib
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent / "src"))
from app import add


def test_add():
    assert add(2, 3) == 5
    assert add(-1, 1) == 0
