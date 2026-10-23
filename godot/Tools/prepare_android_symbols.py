#!/usr/bin/env python3
"""Prepare matching official native symbols for exactly the libraries in a Play AAB."""
import argparse
import io
import json
import mmap
from pathlib import Path
import ssl
import struct
import tempfile
import urllib.request
import zipfile
import zlib


def build_id(data):
    """Read ELF GNU build IDs without requiring an Android NDK installation."""
    if data[:4] != b'\x7fELF':
        raise ValueError('Not an ELF library')
    endian = '<' if data[5] == 1 else '>'
    wide = data[4] == 2
    header = struct.unpack_from(endian + ('16sHHIQQQIHHHHHH' if wide else '16sHHIIIIIHHHHHH'), data)
    offset, stride, count = header[6], header[11], header[12]
    section_format = endian + ('IIQQQQIIQQ' if wide else 'IIIIIIIIII')
    for index in range(count):
        section = struct.unpack_from(section_format, data, offset + index * stride)
        if section[1] != 7:  # SHT_NOTE
            continue
        cursor, end = section[4], section[4] + section[5]
        while cursor + 12 <= end:
            namesize, descsize, kind = struct.unpack_from(endian + 'III', data, cursor)
            cursor += 12
            name = data[cursor:cursor + namesize]
            cursor += (namesize + 3) & ~3
            value = data[cursor:cursor + descsize]
            cursor += (descsize + 3) & ~3
            if kind == 3 and name.rstrip(b'\0') == b'GNU':
                return bytes(value).hex()
    raise ValueError('Missing GNU build ID')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('bundle', type=Path)
    parser.add_argument('--godot-version', default='4.7.2')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    output = args.output or args.bundle.with_name('native-debug-symbols.zip')
    context = ssl.create_default_context(cafile='/etc/ssl/cert.pem' if Path('/etc/ssl/cert.pem').exists() else None)

    def request(url, **kwargs):
        return urllib.request.urlopen(urllib.request.Request(url, **kwargs), context=context, timeout=180)

    release_url = f'https://api.github.com/repos/godotengine/godot/releases/tags/{args.godot_version}-stable'
    with request(release_url) as response:
        release = json.load(response)
    name = f'Godot_native_debug_symbols.{args.godot_version}.stable.template_release.android.zip'
    asset = next(item for item in release['assets'] if item['name'] == name)
    with request(asset['browser_download_url'], method='HEAD') as response:
        url = response.url

    def range_bytes(start, end):
        with request(url, headers={'Range': f'bytes={start}-{end}'}) as response:
            if response.status != 206:
                raise ValueError('Release host did not honor byte range request')
            return response.read()

    # Read ZIP index without fetching architectures absent from the game.
    tail = range_bytes(asset['size'] - 65557, asset['size'] - 1)
    footer_start = tail.rfind(b'PK\x05\x06')
    footer = bytearray(tail[footer_start:])
    fields = struct.unpack_from('<4s4H2LH', footer)
    central_size, central_offset = fields[5:7]
    central = range_bytes(central_offset, central_offset + central_size - 1)
    struct.pack_into('<L', footer, 16, 0)
    with zipfile.ZipFile(io.BytesIO(central + footer)) as index:
        members = {item.filename: item for item in index.infolist()}
    output.parent.mkdir(parents=True, exist_ok=True)
    report = {}
    with zipfile.ZipFile(args.bundle) as bundle, tempfile.TemporaryDirectory(dir=output.parent) as temporary:
        temporary = Path(temporary)
        for library in bundle.namelist():
            if not library.startswith('base/lib/') or not library.endswith('.so'):
                continue
            relative = library.removeprefix('base/lib/')
            item = members[relative]
            header = range_bytes(item.header_offset, item.header_offset + 29)
            name_length, extra_length = struct.unpack_from('<HH', header, 26)
            start = item.header_offset + 30 + name_length + extra_length
            target = temporary / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            print(f'Downloading {relative} ({item.compress_size / 1e6:.1f} MB)', flush=True)
            decoder = zlib.decompressobj(-15) if item.compress_type == 8 else None
            crc, written = 0, 0
            with target.open('wb') as stream:
                for position in range(start, start + item.compress_size, 8 * 1024 * 1024):
                    chunk = range_bytes(position, min(position + 8 * 1024 * 1024, start + item.compress_size) - 1)
                    raw = decoder.decompress(chunk) if decoder else chunk
                    stream.write(raw)
                    crc = zlib.crc32(raw, crc)
                    written += len(raw)
            if written != item.file_size or crc != item.CRC:
                raise ValueError(f'Symbol archive CRC/size mismatch: {relative}')
            expected = build_id(bundle.read(library))
            with target.open('rb') as stream, mmap.mmap(stream.fileno(), 0, access=mmap.ACCESS_READ) as data:
                actual = build_id(data)
            if actual != expected:
                raise ValueError(f'Symbol build ID does not match shipped library: {relative}')
            report[relative] = actual
            print(f'Verified build ID: {actual}', flush=True)
        with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
            for relative in report:
                archive.write(temporary / relative, relative)
    output.with_suffix('.build-ids.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'Prepared {output} ({output.stat().st_size / 1e6:.1f} MB)', flush=True)


if __name__ == '__main__':
    main()
