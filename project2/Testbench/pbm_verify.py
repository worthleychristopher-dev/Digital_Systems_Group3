#to run: python pbm_verify.py mandelbrot_800x600.pbm
import sys


def load_pbm(filename):
    with open(filename, "r") as f:
        tokens = []
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            tokens.extend(line.split())

    if tokens[0] != "P1":
        raise ValueError("Only ASCII PBM (P1) is supported.")

    w = int(tokens[1])
    h = int(tokens[2])

    data = [int(x) for x in tokens[3:3 + w * h]]
    if len(data) != w * h:
        raise ValueError(f"Expected {w*h} pixels, found {len(data)}")

    img = [data[i * w:(i + 1) * w] for i in range(h)]
    return img, w, h


def count_isolated_pixels(img, w, h, target):
    count = 0
    other = 1 - target

    for y in range(1, h - 1):
        for x in range(1, w - 1):
            if img[y][x] == target:
                n = [
                    img[y - 1][x],
                    img[y + 1][x],
                    img[y][x - 1],
                    img[y][x + 1],
                ]
                if all(v == other for v in n):
                    count += 1
    return count


def main():
    if len(sys.argv) < 2:
        print("usage: python pbm_verify.py image.pbm")
        return

    img, w, h = load_pbm(sys.argv[1])

    black_pixels = sum(1 for row in img for p in row if p == 0)
    white_pixels = sum(1 for row in img for p in row if p == 1)

    isolated_black = count_isolated_pixels(img, w, h, 0)
    isolated_white = count_isolated_pixels(img, w, h, 1)

    print("resolution:", w, "x", h)
    print("black pixels:", black_pixels)
    print("white pixels:", white_pixels)
    print("isolated black speckles:", isolated_black)
    print("isolated white speckles:", isolated_white)

    if isolated_black > 50 or isolated_white > 50:
        print("WARNING: noticeable speckle artifacts detected")
    else:
        print("OK: no obvious speckle artifact problem detected")


if __name__ == "__main__":
    main()