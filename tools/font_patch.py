"""
tools/font_patch.py
Fable III (PC) Font (.bft) Patching Utility

Supported Modes:
  - redirect      (Test 4a): Modifies only charmap (ğ->g, ş->s, ı->i), texture and metrics untouched.
  - clone_metrics (Test 4b): Appends 6 glyph records with base UVs, updates charmap, texture untouched.
  - full_patch    (Test 4c): Appends 6 glyph records pointing to Row 14, draws synthesized glyphs into empty texture space.
"""

import sys
import struct
import numpy as np
from PIL import Image

TURKISH_MAPPING = {
    'ğ': (0x011F, 71,  'g'),
    'Ğ': (0x011E, 39,  'G'),
    'ş': (0x015F, 83,  's'),
    'Ş': (0x015E, 51,  'S'),
    'ı': (0x0131, 73,  'i'),
    'İ': (0x0130, 41,  'I'),
}

def patch_font(input_path, output_path, mode='full_patch'):
    with open(input_path, 'rb') as f:
        data = bytearray(f.read())
    
    total_len = len(data)
    tex_len = 1048576
    header_and_metrics_len = total_len - tex_len
    
    # Header parse
    # byte 21..25: glyph_count
    orig_glyph_count = struct.unpack('<I', data[21:25])[0]
    metrics_start = 25
    orig_metrics_end = metrics_start + orig_glyph_count * 28
    
    # Charmap count at orig_metrics_end
    charmap_count = struct.unpack('<I', data[orig_metrics_end:orig_metrics_end+4])[0]
    charmap_start = orig_metrics_end + 4
    orig_charmap_end = charmap_start + charmap_count * 2
    
    # Tail descriptor is between orig_charmap_end and texture start
    tail_desc = data[orig_charmap_end:header_and_metrics_len]
    raw_tex = data[-tex_len:]
    
    print(f"Loaded {input_path}:")
    print(f"  Orig glyph count: {orig_glyph_count}")
    print(f"  Charmap count:    {charmap_count}")
    print(f"  Mode:             {mode}")
    
    if mode == 'redirect':
        # Mode 4a: Only edit charmap entries
        out_data = bytearray(data)
        charmap_offset = charmap_start
        for ch, (cp, base_idx, _) in TURKISH_MAPPING.items():
            pos = charmap_offset + cp * 2
            struct.pack_into('<H', out_data, pos, base_idx)
            print(f"  Redirected {ch} (U+{cp:04X}) -> glyph {base_idx}")
            
    elif mode == 'clone_metrics':
        # Mode 4b: Add 6 glyph records copying base UVs and metrics, leave texture untouched
        new_glyph_count = orig_glyph_count + 6
        header = bytearray(data[:21]) + struct.pack('<I', new_glyph_count)
        
        # Original metrics
        metrics = bytearray(data[metrics_start:orig_metrics_end])
        
        # Append 6 cloned metric records
        new_indices = {}
        for i, (ch, (cp, base_idx, _)) in enumerate(TURKISH_MAPPING.items()):
            new_idx = orig_glyph_count + i
            new_indices[ch] = (cp, new_idx)
            base_rec = data[metrics_start + base_idx * 28 : metrics_start + (base_idx + 1) * 28]
            metrics.extend(base_rec)
            
        # Charmap
        charmap_bytes = bytearray(data[charmap_start:orig_charmap_end])
        for ch, (cp, new_idx) in new_indices.items():
            struct.pack_into('<H', charmap_bytes, cp * 2, new_idx)
            print(f"  Mapped {ch} (U+{cp:04X}) -> cloned glyph {new_idx}")
            
        out_data = header + metrics + struct.pack('<I', charmap_count) + charmap_bytes + tail_desc + raw_tex

    elif mode == 'full_patch':
        # Mode 4c: Synthesize 6 glyphs into Row 14, append metric records, update charmap
        new_glyph_count = orig_glyph_count + 6
        header = bytearray(data[:21]) + struct.pack('<I', new_glyph_count)
        metrics = bytearray(data[metrics_start:orig_metrics_end])
        
        # Load 512x512 RGBA texture
        atlas = Image.frombytes('RGBA', (512, 512), bytes(raw_tex))
        
        def get_arr(x, y):
            return np.array(atlas.crop((x, y, x+32, y+32)))
            
        g_arr = get_arr(224, 128)
        G_arr = get_arr(224, 64)
        s_arr = get_arr(96, 160)
        S_arr = get_arr(96, 96)
        i_arr = get_arr(288, 128)
        I_arr = get_arr(288, 64)
        cc_arr = get_arr(128, 288) # ç
        
        # 1. Cedilla patch
        cedilla_patch = np.full((32, 32, 4), 255, dtype=np.uint8)
        for r in range(25, 32):
            for c in range(9, 23):
                if cc_arr[r, c, 0] < 195:
                    cedilla_patch[r, c] = cc_arr[r, c]

        s_cedilla = np.minimum(s_arr, cedilla_patch)

        S_shifted = np.full_like(S_arr, 255)
        S_shifted[0:30, :] = S_arr[2:32, :]
        S_shifted[30:32, :] = S_arr[31:32, :]
        S_cedilla = np.minimum(S_shifted, cedilla_patch)

        # 2. Dotless i
        dotless_i = i_arr.copy()
        for r in range(3, 11):
            left_val = i_arr[r, 9, :].astype(float)
            right_val = i_arr[r, 23, :].astype(float)
            for c in range(10, 23):
                t = (c - 9) / 14.0
                dotless_i[r, c, :] = np.clip(left_val * (1.0 - t) + right_val * t, 0, 255).astype(np.uint8)

        # 3. Dotted I
        I_shifted = np.full_like(I_arr, 255)
        I_shifted[2:32, :] = I_arr[0:30, :]
        I_shifted[0:2, :] = I_arr[0:1, :]
        dot_patch = np.full((32, 32, 4), 255, dtype=np.uint8)
        for r in range(5, 10):
            for c in range(11, 21):
                if i_arr[r, c, 0] < 195:
                    dot_patch[r-5, c] = i_arr[r, c]
        dotted_I = np.minimum(I_shifted, dot_patch)

        # 4. Breve (U biçimli, ö/ü nokta kalınlığında): SDF'de görünür mürekkep ~<125 değerleridir; ö/Ö noktalarının çekirdeği ~3 px.
        #    Yay boyunca SDF = min(240, 114 + 12 * uzaklık) -> ~2 px çekirdek (v1.0.2'deki ince yay 118+35*d idi: ~0,4 px, neredeyse görünmezdi).
        def breve_patch_for(base_arr, y_bot, depth, hw):
            ys_, xs_ = np.where(base_arr[:, :, 0] < 150)
            cx = (xs_.min() + xs_.max()) / 2.0
            px = np.linspace(cx - hw, cx + hw, 80)
            py = y_bot - depth * ((px - cx) / hw) ** 2
            yy, xx = np.mgrid[0:32, 0:32]
            dmin = np.full((32, 32), 99.0)
            for x_, y_ in zip(px, py):
                dmin = np.minimum(dmin, np.hypot(xx - x_, yy - y_))
            v = np.minimum(240.0, 114.0 + 12.0 * dmin).astype(np.uint8)
            out = np.empty((32, 32, 4), dtype=np.uint8)
            for ch in range(4):
                out[:, :, ch] = v
            return out

        g_breve = np.minimum(g_arr, breve_patch_for(g_arr, 8.0, 3.0, 5.2))
        G_breve = np.minimum(G_arr, breve_patch_for(G_arr, 3.8, 2.0, 5.2))

        new_glyphs = [
            ('ğ', g_breve,   71, 0),
            ('Ğ', G_breve,   39, 1),
            ('ş', s_cedilla, 83, 2),
            ('Ş', S_cedilla, 51, 3),
            ('ı', dotless_i, 73, 4),
            ('İ', dotted_I,  41, 5),
        ]
        
        # Paste synthesized glyphs into Row 14 (Y=448..480)
        row14_y = 448
        for ch, patch_arr, base_idx, col in new_glyphs:
            cell_x = col * 32
            patch_img = Image.fromarray(patch_arr, 'RGBA')
            atlas.paste(patch_img, (cell_x, row14_y))
            
            # Metric record: UV points to (cell_x + 0.5, row14_y + 0.5) to (cell_x + 31.5, row14_y + 31.5)
            u0 = (cell_x + 0.5) / 512.0
            v0 = (row14_y + 0.5) / 512.0
            u1 = (cell_x + 31.5) / 512.0
            v1 = (row14_y + 31.5) / 512.0
            
            # Read base bearing and advance
            _, _, _, _, bx, by, adv = struct.unpack('<7f', data[metrics_start + base_idx * 28 : metrics_start + (base_idx + 1) * 28])
            metrics.extend(struct.pack('<7f', u0, v0, u1, v1, bx, by, adv))

        # Charmap
        charmap_bytes = bytearray(data[charmap_start:orig_charmap_end])
        for i, (ch, _, _, _) in enumerate(new_glyphs):
            cp, _, _ = TURKISH_MAPPING[ch]
            new_idx = orig_glyph_count + i
            struct.pack_into('<H', charmap_bytes, cp * 2, new_idx)
            print(f"  Mapped {ch} (U+{cp:04X}) -> new glyph {new_idx} (Row 14, Col {i})")

        new_tex_bytes = atlas.tobytes()
        out_data = header + metrics + struct.pack('<I', charmap_count) + charmap_bytes + tail_desc + new_tex_bytes
    else:
        raise ValueError(f"Unknown mode: {mode}")
        
    with open(output_path, 'wb') as f:
        f.write(out_data)
        
    print(f"Wrote {len(out_data)} bytes to {output_path}")

if __name__ == '__main__':
    if len(sys.argv) < 4:
        print("Usage: python font_patch.py <input.bft> <output.bft> <redirect|clone_metrics|full_patch>")
        sys.exit(1)
    patch_font(sys.argv[1], sys.argv[2], sys.argv[3])
