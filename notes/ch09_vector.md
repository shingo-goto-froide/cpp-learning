# 第9章: vector

## 要点

### std::vector — 動的配列

- C#の`List<T>`に相当する動的配列

```cpp
std::vector<int> v = {1, 2, 3};
v.push_back(4);       // 末尾に追加
std::cout << v.size(); // 要素数: 4
std::cout << v[0];     // 要素アクセス: 1
```

### at() — 範囲チェック付きアクセス

- `[]`は範囲チェックなし（範囲外は未定義動作）
- `at()`は範囲外で`std::out_of_range`例外を投げる

```cpp
std::vector<int> v = {1, 2, 3};

v[5];      // 未定義動作（何が起きるかわからない）
v.at(5);   // std::out_of_range 例外を投げる
```

### std::size_t型

- `size()`の戻り値は`std::size_t`（符号なし整数型）
- `int`と混ぜると警告が出る

```cpp
std::vector<int> v = {1, 2, 3};

// 警告: signedとunsignedの比較
for (int i = 0; i < v.size(); ++i) { }

// OK
for (std::size_t i = 0; i < v.size(); ++i) { }
```

| | `int` | `std::size_t` |
|---|---|---|
| 符号 | あり（負の値OK） | なし（0以上のみ） |
| 用途 | 一般的な整数 | サイズや要素数 |
| ビット幅 | 通常32bit | 環境依存（64bit環境では64bit） |

### std名前空間

- `std`は標準ライブラリの名前空間（C#の`System`に相当）
- `using namespace std;`で省略できるが、名前衝突のリスクがあり**非推奨**

```cpp
std::vector<int> v;    // std名前空間のvector
std::string s;         // std名前空間のstring
std::cout << "hello";  // std名前空間のcout
```

### 前置インクリメント vs 後置インクリメント

- 式としての値が異なる

```cpp
int i = 0;
int a = ++i;  // iを先に増やしてから返す → a=1, i=1
int b = i++;  // 返してからiを増やす   → b=1, i=2
```

- ループでは結果に差はないが、C++では**前置（`++i`）が慣習**
- イテレータなどクラス型では後置にコピーコストがかかるため

```cpp
for (std::size_t i = 0; i < v.size(); ++i)  // C++の慣習
```

### 選択ソート

- 「未ソート部分から最小値を見つけて先頭と交換」を繰り返すアルゴリズム

```cpp
auto selection_sort = [](auto & v) {
    for (std::size_t i = 0; i < v.size(); ++i) {
        std::size_t min_index = i;
        for (std::size_t j = i + 1; j < v.size(); ++j) {
            if (v[j] < v[min_index]) {
                min_index = j;
            }
        }
        std::swap(v[i], v[min_index]);
    }
};
```

- 計算量はO(n²)で、要素数が増えると急激に遅くなる
- 実務では`std::sort`（O(n log n)）を使う

```cpp
std::sort(v.begin(), v.end());
```

### 計算量（Big O）の大小比較

速い ← O(1) < O(log n) < O(n) < O(n log n) < O(n²) < O(2ⁿ) → 遅い

| 表記 | 名前 | 例 |
|---|---|---|
| O(1) | 定数 | 配列の添字アクセス `v[i]` |
| O(log n) | 対数 | 二分探索 |
| O(n) | 線形 | 線形探索、`std::find` |
| O(n log n) | 線形対数 | `std::sort`、マージソート |
| O(n²) | 二乗 | 選択ソート、バブルソート |
| O(2ⁿ) | 指数 | 全組み合わせ探索 |

## C#との比較

| 項目 | C# | C++ |
|------|-----|------|
| 動的配列 | `List<T>` | `std::vector<T>` |
| 追加 | `Add(x)` | `push_back(x)` |
| 要素数 | `Count`（プロパティ） | `size()`（関数） |
| 要素アクセス | `v[i]`（範囲チェックあり） | `v[i]`（チェックなし）/ `v.at(i)`（チェックあり） |
| サイズの型 | `int` | `std::size_t`（符号なし） |
| 標準名前空間 | `System`（`using`で省略可） | `std`（省略は非推奨） |
| インクリメント慣習 | `i++` | `++i` |
| ソート | `List.Sort()` / `OrderBy()` | `std::sort()` |

## 補足

### `using namespace std;`を避ける理由

- 標準ライブラリには大量の名前が定義されている
- 自分で定義した関数や変数と名前が衝突するリスクがある
- ヘッダーファイルに書くと、そのヘッダーをincludeした全ファイルに影響が波及する
- 毎回`std::`と書くのがC++の標準的なスタイル

### 実務でのソートアルゴリズム選択

- 自分でソートを実装する必要はほぼない
- `std::sort`は内部的にイントロソート（クイックソート+ヒープソート+挿入ソート）を使用
- C#の`List.Sort()`も同じくO(n log n)のアルゴリズム

## 理解度

- [x] std::vectorの基本操作（追加、アクセス、サイズ取得）
- [x] at()と[]の違い（範囲チェック）
- [x] std::size_t型とintの違い
- [x] std名前空間の役割
- [x] 前置・後置インクリメントの違いとC++の慣習
- [x] 選択ソートのアルゴリズム
- [x] 計算量（Big O）の大小関係
