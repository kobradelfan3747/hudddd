"""Build vn-hud's rounded rectangular DXT1 radar mask.

This is a development tool only; FiveM does not run it.
The streamed YTD keeps the stock 512x256 radar-mask layout while increasing
only the corner radius of the visible rectangle.
"""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

WIDTH = 512
HEIGHT = 256
RECT = (59, 43, 328, 213)
SUPERSAMPLE = 4


def inside_rounded_rect(x: float, y: float, radius: float) -> bool:
    left, top, right, bottom = RECT

    if x < left or x >= right or y < top or y >= bottom:
        return False

    nearest_x = min(max(x, left + radius), right - radius)
    nearest_y = min(max(y, top + radius), bottom - radius)
    dx = x - nearest_x
    dy = y - nearest_y
    return (dx * dx) + (dy * dy) <= radius * radius


def create_mask(radius: int) -> list[int]:
    mask = [0] * (WIDTH * HEIGHT)
    samples = SUPERSAMPLE * SUPERSAMPLE

    for y in range(RECT[1], RECT[3]):
        for x in range(RECT[0], RECT[2]):
            covered = 0

            for sample_y in range(SUPERSAMPLE):
                for sample_x in range(SUPERSAMPLE):
                    point_x = x + ((sample_x + 0.5) / SUPERSAMPLE)
                    point_y = y + ((sample_y + 0.5) / SUPERSAMPLE)
                    covered += inside_rounded_rect(point_x, point_y, radius)

            mask[(y * WIDTH) + x] = round((covered / samples) * 255)

    return mask


def encode_dxt1(mask: list[int]) -> bytes:
    # DXT1 palette: white, black, 2/3 white, 1/3 white.
    levels = (255, 0, 170, 85)
    output = bytearray()

    for block_y in range(0, HEIGHT, 4):
        for block_x in range(0, WIDTH, 4):
            indices = 0

            for local_y in range(4):
                for local_x in range(4):
                    value = mask[((block_y + local_y) * WIDTH) + block_x + local_x]
                    palette_index = min(range(4), key=lambda index: abs(levels[index] - value))
                    shift = 2 * ((local_y * 4) + local_x)
                    indices |= palette_index << shift

            output.extend(struct.pack('<HHI', 0xFFFF, 0x0000, indices))

    return bytes(output)


def rebuild_ytd(path: Path, radius: int) -> None:
    resource = path.read_bytes()
    if resource[:4] != b'RSC7':
        raise ValueError('The input is not an RSC7 texture dictionary.')

    raw = bytearray(zlib.decompress(resource[16:], -15))
    expected_size = WIDTH * HEIGHT // 2
    texture_offset = len(raw) - expected_size

    if raw[0x98:0x9C] != b'DXT1':
        raise ValueError('Expected a DXT1 radarmasksm texture.')
    if b'radarmasksm' not in raw[:0x200]:
        raise ValueError('Expected the radarmasksm texture name.')

    raw[texture_offset:] = encode_dxt1(create_mask(radius))

    compressor = zlib.compressobj(level=9, wbits=-15)
    compressed = compressor.compress(bytes(raw)) + compressor.flush()
    path.write_bytes(resource[:16] + compressed)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--radius', type=int, default=18, help='corner radius in source-mask pixels')
    parser.add_argument('--file', type=Path, default=Path('stream/rectmap.ytd'))
    args = parser.parse_args()

    if not 4 <= args.radius <= 60:
        parser.error('--radius must be between 4 and 60')

    rebuild_ytd(args.file, args.radius)
    print(f'Built {args.file} with corner radius {args.radius}px')
