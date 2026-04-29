# 第30章: std::vectorの実装

## 要点

### `std::allocator<T>` の使い方

**「型Tのための型安全なメモリー確保器」**。`operator new` と `malloc` の中間的な立ち位置。

```cpp
#include <memory>

std::allocator<int> alloc;

// ① 確保：int N個分のメモリー（型付き！ void* ではない）
int* p = alloc.allocate(5);

// ② 構築：確保した領域にオブジェクトを作る
std::construct_at(p,     42);
std::construct_at(p + 1, 100);

// ③ 破棄：デストラクタ呼出
std::destroy_at(p);
std::destroy_at(p + 1);

// ④ 解放
alloc.deallocate(p, 5);
```

### `allocator` の特徴

| 項目 | 内容 |
|---|---|
| 戻り値 | **`T*`**（型安全、キャスト不要） |
| 確保単位 | **要素数**（バイト数ではない） |
| コンストラクタ | 呼ばない（別途 `construct_at`） |
| デストラクタ | 呼ばない（別途 `destroy_at`） |
| 失敗時 | `std::bad_alloc` |

### `malloc` / `new` / `allocator` の比較

| | メモリー | 型 | 構築 | 単位 |
|---|---|---|---|---|
| `malloc(n)` | 生 | `void*` | ✗ | バイト |
| `new T` | 生 | `T*` | ○ | 1個 |
| `new T[n]` | 生 | `T*` | ○（全部） | n個 |
| `allocator::allocate(n)` | 生 | `T*` | ✗ | **n個** |

### アロケーターの本質

「複数確保するためのもの」ではなく、次の3つが本質：

1. **型安全な生メモリー確保**（`T*` を返す）
2. **確保と構築を分離できる**（`reserve` のために必須）
3. **差し替え可能な戦略**（コンテナに独自の確保方法を注入）

```cpp
std::vector<int>                       v1;   // 標準アロケーター
std::vector<int, MyPoolAllocator<int>>  v2;  // 自作プールに置く
```

### C++17以前の古い書き方（非推奨）

```cpp
alloc.construct(p, 42);    // C++17で非推奨、C++20で削除
alloc.destroy(p);          // 同上
```

C++20以降は `std::construct_at` / `std::destroy_at` を使う。

### vector内部の3つのポインター

```cpp
template<typename T>
class vector {
    T* first;          // 先頭（begin）
    T* last;           // 構築済み要素の末尾の次（end）
    T* reserved_last;  // 確保済みメモリーの末尾の次
};
```

メモリー図：

```
           first         last            reserved_last
             ↓             ↓                    ↓
           ┌───┬───┬───┬───┬───┬───┬───┬───┐
           │ 1 │ 2 │ 3 │   │   │   │   │   │
           └───┴───┴───┴───┴───┴───┴───┴───┘
           ←─ size=3 ─→
           ←────────── capacity=8 ──────────→
```

| 関数 | 計算 |
|---|---|
| `size()`     | `last - first` |
| `capacity()` | `reserved_last - first` |
| `empty()`    | `first == last` |

### なぜ `size` と `capacity` を分けるか

**メモリー再確保を減らすため**。

```cpp
std::vector<int> v;
v.reserve(100);     // capacity=100 を一気に確保
// size=0, capacity=100

v.push_back(1);     // 構築するだけ、再確保不要
v.push_back(2);     // last++ だけで済む
```

### `push_back` の内部動作

```cpp
void push_back(const T& value) {
    if (last == reserved_last) {
        reallocate();   // 領域が尽きた → 再確保（通常2倍成長）
    }
    std::construct_at(last, value);   // 構築
    ++last;                            // 末尾を進める
}
```

成長のイメージ：

```cpp
std::vector<int> v;
v.push_back(1);   // size=1, capacity=1
v.push_back(2);   // size=2, capacity=2（再確保）
v.push_back(3);   // size=3, capacity=4（再確保、2倍成長）
v.push_back(5);   // size=5, capacity=8（再確保）
```

### 半開区間 `[first, last)`

- `first` は最初の要素を指す（**含む**）
- `last` は**最後の要素の次**を指す（**含まない**）
- STL全体がこの規約で統一されている

#### 半開区間の利点

1. **ループが自然**：`for (it = begin; it != end; ++it)` で `!=` だけで終了判定
2. **空を自然表現**：`first == last` なら要素0個
3. **サイズが引き算のみ**：`last - first` が個数
4. **範囲を連結可能**：`[a,b) + [b,c) = [a,c)` と `b` を重複なく使える

### `end()` は番兵（sentinel）

- `end()` が指す位置は**実在しない**
- ループ終了のための目印
- デリファレンス（`*end()`）は未定義動作

### 名前の整理：begin/end, front/back, first/last

| 名前 | 何か | 返すもの |
|---|---|---|
| `begin()` | 公開関数 | イテレーター（先頭を指す） |
| `end()` | 公開関数 | イテレーター（末尾の次を指す） |
| `front()` | 公開関数 | **要素の参照**（先頭要素そのもの） |
| `back()` | 公開関数 | **要素の参照**（最後の要素そのもの） |
| `first` | 内部のメンバー変数 | （実装者が付けた名前） |
| `last` | 内部のメンバー変数 | （実装者が付けた名前） |

```cpp
*v.begin()       == v.front();   // true
*(v.end() - 1)   == v.back();    // true（ランダムアクセスの場合）
```

### 型エイリアスの公開（復習）

```cpp
template<typename T>
class vector {
public:
    using value_type     = T;
    using iterator       = T*;
    using const_iterator = const T*;
    using reference      = T&;
    using size_type      = std::size_t;
};
```

- テンプレートパラメータ `T` は**外から見えない**（`vector::T` は不可）
- 外から型を取り出すには**公開メンバーとして型エイリアス**が必要
- 利用側は `typename Container::value_type` 等で取得

### 変換コンストラクター

**引数1つのコンストラクター**はデフォルトで暗黙変換に使われる。

```cpp
class Fraction {
    int num, den;
public:
    Fraction(int n) : num(n), den(1) {}   // int → Fraction の変換
};

Fraction f = 5;           // int → Fraction に暗黙変換
void print(Fraction f);
print(3);                  // 3 が Fraction(3) に変換されて渡る
```

### `explicit` で暗黙変換を禁止

```cpp
class Fraction {
public:
    explicit Fraction(int n) : num(n), den(1) {}
};

Fraction f = 5;           // ❌ エラー
Fraction f(5);            // ✅ 明示的ならOK
Fraction f{5};            // ✅
print(Fraction(5));       // ✅
```

- 意味的に「変換」として自然なら付けない選択もアリ
- 単なる初期化用なら `explicit` を付ける
- **迷ったら付ける**のが現代的作法

### イテレーターの距離

```cpp
// ランダムアクセスイテレーター：引き算で O(1)
auto diff = it2 - it1;        // ✅ vector/array/ポインター

// 統一的に書ける std::distance
auto diff = std::distance(it1, it2);
```

| カテゴリー | 内部動作 | 計算量 |
|---|---|---|
| ランダムアクセス | 引き算 | **O(1)** |
| それ以外 | `++` を数える | **O(n)** |

戻り値の型は **`difference_type`**（通常 `std::ptrdiff_t`、符号付き）。

## C#との比較

| 項目 | C# | C++ |
|---|---|---|
| 動的配列 | `List<T>` | `std::vector<T>` |
| サイズ | `Count` | `size()` |
| 容量 | `Capacity` | `capacity()` |
| 先頭要素 | `list[0]` | `v.front()` or `v[0]` |
| 末尾要素 | `list[Count-1]` | `v.back()` |
| 事前確保 | `list.Capacity = 100` | `v.reserve(100)` |
| アロケーター | なし（GC前提） | `std::allocator<T>` |
| 確保と構築の分離 | 不可 | 可能 |
| 変換演算子 | `implicit/explicit operator` | **コンストラクター**が兼ねる |
| 暗黙変換 | 型側の明示許可が必要 | デフォルトで発動（危険） |
| `explicit` の役割 | 変換演算子に付ける | コンストラクターに付ける |
| イテレーター距離 | なし | ランダムアクセスなら引き算 |

## 補足

### 暗黙変換の防衛策

C++の暗黙変換は落とし穴が多い。以下で防ぐ：

1. **コンストラクターに `explicit`** を付ける
2. **ブレース初期化 `{}`** を使う（縮小変換を禁止）
3. **警告レベルを上げる**（`-Wconversion` など）
4. **`static_cast` で明示変換**
5. **`enum class` で強い型**を作る

```cpp
int x = 3.14;    // ⚠️ 暗黙変換、警告のみ
int x{3.14};     // ❌ エラー（縮小変換を拒否）
```

### エイリアスと型定義の違い

| 構文 | 役割 | 新しい型？ |
|---|---|---|
| `using A = B;` | エイリアス（別名） | ✗ |
| `typedef B A;` | エイリアス（C由来） | ✗ |
| `struct A { ... };` | 型を新規定義 | ✓ |
| `class A { ... };` | 型を新規定義 | ✓ |

`using value_type = T;` は**新しい型を作っていない**。ただ `T` に別名を付けているだけ。

### 型エイリアスで追いにくくなる問題

STL実装は多段のエイリアスで抽象化されている：

```cpp
using iterator = pointer;    // 1段目
using pointer  = T*;         // 2段目
```

対処法：
- 最初の1回だけ「正体」をメモる
- IDEのホバーで実体を確認
- 名前の規約を覚える（`value_type`, `reference`, `size_type` など全STL共通）

### STLの型エイリアス規約

| 名前 | 意味 |
|---|---|
| `value_type` | 要素の型 |
| `reference` / `const_reference` | 要素への参照 |
| `pointer` / `const_pointer` | 要素へのポインター |
| `iterator` / `const_iterator` | 反復子 |
| `size_type` | サイズを表す整数型 |
| `difference_type` | イテレーター間の距離型 |

### アロケーターの実用場面

アプリ実装ではほぼ使わない。主にライブラリ実装者向け：

- `std::vector` などコンテナの内部
- メモリープール / アリーナアロケーター
- 共有メモリー配置
- ゲーム・高頻度取引などの低レイテンシ要求

「`vector` の中身はこれで動いている」と理解しておけば十分。日常は `vector`/`unique_ptr` で済む。

### コンテナ配列の成長戦略

`push_back` が領域を使い切った時、多くの実装は**2倍成長**する。

- 理由：償却計算量が O(1) になる
- 無駄を気にするなら `reserve()` で先に capacity 確保
- `shrink_to_fit()` で余分な capacity を削減可能

### `end()` を指すポインターの合法性

C++標準で**配列の「末尾の次」を指すポインターは合法**と保証されている：

```cpp
int arr[5];
int* p = arr + 5;   // ✅ 指すのはOK
*p;                  // ❌ デリファレンスは未定義動作
p == arr + 5;        // ✅ 比較は OK
```

これによって `[first, last)` の規約が安全に成立する。

## 理解度

- [x] `std::allocator<T>` の4ステップ（allocate → construct_at → destroy_at → deallocate）
- [x] アロケーターの本質（型安全・確保/構築の分離・差し替え可能）
- [x] `malloc`/`new`/`allocator` の使い分け
- [x] vector 内部の3ポインター（first, last, reserved_last）
- [x] size と capacity を分ける理由
- [x] 半開区間 `[first, last)` の利点
- [x] `end()` は番兵（実在しない目印）
- [x] `begin/end`, `front/back`, `first/last` の区別
- [x] テンプレートパラメータ `T` は外から見えない
- [x] 型エイリアスは新しい型を作らない
- [x] 変換コンストラクターと `explicit` の使い分け
- [x] 暗黙変換の落とし穴と防衛策
- [x] イテレーターの距離（引き算 vs `std::distance`）

## 次章へ

vectorの基本構造を学んだので、次はより詳細な実装（`push_back`/`pop_back`/`insert`/`erase` の実装、例外安全、ムーブセマンティクスとの連携）に進むと思われる。
