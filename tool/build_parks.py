#!/usr/bin/env python3
"""공공데이터포털 '파크골프장 표준데이터' CSV → assets/data/parks.json

사용법:
    python3 tool/build_parks.py 내려받은CSV1.csv [CSV2.csv ...] > assets/data/parks.json

- 기관별로 나뉜 표준데이터 CSV 여러 개를 한 번에 넣을 수 있어요.
- 인코딩은 UTF-8 / CP949(EUC-KR) 를 자동으로 시도해요.
- 이름 + 주소가 같은 줄은 하나로 합쳐요.
- 앱은 이름 · 주소 · 지역 · 홀수 · 코스수만 써요 (홀별 파는 사용자가 탭으로 입력).
"""
import csv
import hashlib
import io
import json
import sys

NAME = ['파크골프장명', '시설명', '골프장명']
ROAD = ['소재지도로명주소', '도로명주소']
JIBUN = ['소재지지번주소', '지번주소']
HOLES = ['홀수', '총홀수']
COURSES = ['코스수', '코스 수']


def pick(row, keys):
    for k in keys:
        for col in row:
            if col and col.replace(' ', '') == k.replace(' ', ''):
                v = (row[col] or '').strip()
                if v:
                    return v
    return ''


def to_int(v):
    digits = ''.join(ch for ch in v if ch.isdigit())
    return int(digits) if digits else 0


def read(path):
    raw = open(path, 'rb').read()
    for enc in ('utf-8-sig', 'cp949'):
        try:
            return list(csv.DictReader(io.StringIO(raw.decode(enc))))
        except UnicodeDecodeError:
            continue
    raise SystemExit(f'인코딩을 알 수 없어요: {path}')


def main(paths):
    seen = {}
    for path in paths:
        for row in read(path):
            name = pick(row, NAME)
            if not name:
                continue
            address = pick(row, ROAD) or pick(row, JIBUN)
            holes = to_int(pick(row, HOLES)) or 9
            courses = to_int(pick(row, COURSES)) or max(1, -(-holes // 9))
            region = ' '.join(address.split()[:2])
            key = (name.replace(' ', ''), address.replace(' ', ''))
            pid = 'pub-' + hashlib.sha1('|'.join(key).encode()).hexdigest()[:12]
            seen[key] = {
                'id': pid,
                'name': name,
                'address': address,
                'region': region,
                'holes': holes,
                'courses': courses,
            }
    parks = sorted(seen.values(), key=lambda p: (p['region'], p['name']))
    json.dump(parks, sys.stdout, ensure_ascii=False, indent=0)
    print(f'{len(parks)}곳', file=sys.stderr)


if __name__ == '__main__':
    if len(sys.argv) < 2:
        raise SystemExit(__doc__)
    main(sys.argv[1:])
