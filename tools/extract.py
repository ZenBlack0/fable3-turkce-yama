"""
Fable III Text Extraction Tool (Enhanced)
Extracts all strings from book.babel into CSV and JSON.
Detects and lists control codes/tags (brackets, formatting tags, printf placeholders, newlines).
"""

import sys
import os
import zlib
import struct
import csv
import json
import re

TAG_REGEX = re.compile(r'(<[^>]+>|\[[A-Za-z0-9_:\s-]+\]|%[0-9.]*[sdfiux]|%[A-Za-z0-9_]+%|\\n|\n)')

def extract_tags(text):
    if not text:
        return []
    matches = TAG_REGEX.findall(text)
    # clean newlines display
    cleaned = []
    for m in matches:
        if m in ('\n', '\\n'):
            cleaned.append('\\n')
        else:
            cleaned.append(m)
    return cleaned

def extract_strings(babel_path, out_csv=None, out_json=None):
    if not os.path.exists(babel_path):
        raise FileNotFoundError(f"File not found: {babel_path}")

    with open(babel_path, 'rb') as f:
        data = f.read()

    num_entries = struct.unpack('>I', data[4:8])[0]
    pos = 8 + num_entries * 12
    num_blocks = struct.unpack('>I', data[pos:pos+4])[0]
    pos += 4

    blocks = []
    block_w1_map = {}
    for b in range(num_blocks):
        w1, comp_sz, uncomp_sz = struct.unpack('>3I', data[pos:pos+12])
        block_offset = pos + 12
        chunk = data[block_offset : block_offset + comp_sz]
        dec = zlib.decompressobj().decompress(chunk)
        blocks.append(dec)
        block_w1_map[w1] = b
        pos = block_offset + comp_sz

    records = []
    unique_texts = set()

    for e in range(num_entries):
        eid, f2, f3 = struct.unpack('>3I', data[8+e*12 : 8+(e+1)*12])
        b_idx = block_w1_map[f2]
        b_data = blocks[b_idx]
        str_len = struct.unpack('>I', b_data[f3:f3+4])[0]
        raw_str = b_data[f3+4 : f3+4+str_len*2]
        text = raw_str.decode('utf-16be', errors='replace').rstrip('\x00')
        unique_texts.add(text)
        tags = extract_tags(text)

        records.append({
            'id': f'0x{eid:08X}',
            'index': e,
            'block_idx': b_idx,
            'block_tag': f'0x{f2:08X}',
            'offset': f3,
            'length': str_len,
            'original_text': text,
            'ceviri': '',
            'tags': ' '.join(tags) if tags else '',
            'not': ''
        })

    print(f"Total strings extracted: {len(records):,}")
    print(f"Unique strings: {len(unique_texts):,} (duplicate saving: {len(records) - len(unique_texts):,})")

    if out_csv:
        os.makedirs(os.path.dirname(out_csv), exist_ok=True)
        with open(out_csv, 'w', encoding='utf-8-sig', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['id', 'file', 'orijinal_metin', 'ceviri', 'etiketler', 'not'])
            for r in records:
                writer.writerow([r['id'], 'book.babel', r['original_text'], r['ceviri'], r['tags'], r['not']])
        print(f"Exported {len(records)} entries to CSV: {out_csv}")

    if out_json:
        os.makedirs(os.path.dirname(out_json), exist_ok=True)
        with open(out_json, 'w', encoding='utf-8') as f:
            json.dump(records, f, ensure_ascii=False, indent=2)
        print(f"Exported {len(records)} entries to JSON: {out_json}")

    return records

if __name__ == '__main__':
    default_babel = r'c:\Games\Fable 3\data\language\en-uk\text\book.babel'
    default_csv = r'C:\Games\Fable3_Turkish_Mod\extracted\en_uk_strings.csv'
    default_json = r'C:\Games\Fable3_Turkish_Mod\extracted\en_uk_strings.json'

    babel_file = sys.argv[1] if len(sys.argv) > 1 else default_babel
    csv_file = sys.argv[2] if len(sys.argv) > 2 else default_csv
    json_file = sys.argv[3] if len(sys.argv) > 3 else default_json

    extract_strings(babel_file, csv_file, json_file)
