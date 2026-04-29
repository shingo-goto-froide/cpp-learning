# 第31章: vectorのコンストラクタと初期化

## 要点

### `nullptr` と `NULL` の違い

C++では **`nullptr` を使う**のが正解。`NULL` は古い書き方で罠あり。

| | `NULL` | `nullptr` |
|---|---|---|
| 正体 | マクロで実体は `0`（整数） | 専用型 `std::nullptr_t` |
| 型安全性 | ✗（整数と区別不可） | ✓ |
| オーバーロード解決 | 誤動作することあり | 正しく解決される |

```cpp
void func(int i);       // ①
void func(int* p);      // ②

func(NULL);    // ①が呼ばれる（NULL=0 = 整数）← 罠
func(nullptr); // ②が呼ばれる ← 期待通り
```

### vectorのアロケーター指定

```cpp
std::vector<int, std::allocator<int>> v;
//           ^^   ^^^^^^^^^^^^^^^^^^
//           要素型  アロケーター型（デフォルトは省略可）

std::allocator<int> my_alloc;
std::vector<int> v1(my_alloc);                // 空、アロケーター指定
std::vector<int> v2(10, my_alloc);            // 要素10個
std::vector<int> v3(10, 42, my_alloc);        // 10個を42で初期化
```

コンストラクタの**最後の引数**としてアロケーターを渡すのが規約。

### カスタムアロケーターの最小要件

```cpp
template<typename T>
class MyAllocator {
public:
    using value_type = T;                      // 必須

    T* allocate(std::size_t n);                // 必須
    void deallocate(T* p, std::size_t n);      // 必須
};
```

C++17以前はより多くのメンバーが必要だったが、今は3つで十分（残りは `std::allocator_traits` が補完）。

### `std::pmr`（C++17）：多態アロケーター

毎回テンプレート引数を書くのが面倒なので、C++17 で**ランタイムに差し替え可能**なアロケーターが追加。

```cpp
#include <memory_resource>

std::array<std::byte, 1024> buffer;
std::pmr::monotonic_buffer_resource pool{buffer.data(), buffer.size()};

std::pmr::vector<int> v{&pool};   // buffer から確保
v.push_back(1);                    // bufferのメモリーを使う
```

ゲーム・組み込み・低レイテンシで重宝する。

### 委譲コンストラクタ（delegating constructor）

**同じクラスの別オーバーロードに初期化を委譲**できる機能（C++11〜）。

```cpp
vector()
    : vector(allocator_type()) {}   // ← 自分の別オーバーロードを呼ぶ

explicit vector(const allocator_type& alloc)
    : alloc_(alloc), first(nullptr), last(nullptr), reserved_last(nullptr) {}
```

### 初期化子リストの2種類の書き方

コロン `:` の後に以下のどちらかを書く：

1. **メンバー変数の初期化** → `alloc_(alloc)`, `first(nullptr)`
2. **他のコンストラクタへの委譲** → `vector(0, T(), ...)`

**1と2は混ぜられない**（委譲すると他のメンバー初期化は書けない）。

### 見分け方

```cpp
: vector(...)      // ← クラス名   → 委譲
: alloc_(...)      // ← メンバー名 → メンバー初期化
```

**`:` の直後がクラス名か、メンバー変数名か**で判断。

### マスターコンストラクタ（Funnel Pattern）

複数のコンストラクタを1本に集約するのが定石。

```cpp
// A: デフォルト → Cに委譲
vector() : vector(0, T(), allocator_type()) {}

// B: サイズ指定 → Cに委譲
vector(size_type n) : vector(n, T(), allocator_type()) {}

// C: マスター（実体）
vector(size_type n, const T& value, const allocator_type& alloc = {})
    : alloc_(alloc)
{
    first = alloc_.allocate(n);
    last = first;
    reserved_last = first + n;
    for (size_type i = 0; i < n; ++i) {
        std::construct_at(last++, value);
    }
}
```

呼び出しの流れ：
```
vector v;           → A → C（マスター）
vector v(10);       → B → C（マスター）
vector v(10, 42);   → C（マスター）直接
                      ↑ すべて結局ここを通る
```

### 委譲のメリット

| メリット | 重要度 |
|---|---|
| 重複排除（DRY） | ★★☆ |
| **修正漏れ防止** | ★★★ |
| **不変条件の保証** | ★★★ |
| テスト容易性 | ★★☆ |

どのコンストラクタを呼んでも**同じ最終状態**が保証される → 「統一しないと怖い」という直感への構造的解決策。

### 4種類の初期化構文

```cpp
Foo a;             // デフォルト初期化
Foo b{};           // 値初期化（推奨、ゼロ埋め）
Foo c = 5;         // コピー初期化
Foo d(5);          // 直接初期化
Foo e{5};          // 直接リスト初期化（推奨）
Foo f = {5};       // コピーリスト初期化
```

**推奨は `{}` 系**（C++11以降）。理由：
- 縮小変換を禁止
- コンストラクタ呼び出しと区別しやすい
- most vexing parse を回避

### `new` なしの初期化（C++の基本）

```cpp
std::vector<int> v = {1, 2, 3};   // ✅ new 不要、これが基本形
```

C++は**スタック上に値型として**オブジェクトを作るのが常識。C#とは発想が逆転。

### ブレース初期化の罠

```cpp
std::vector<int> a(3, 0);   // 直接初期化：(size=3, value=0) → {0,0,0}
std::vector<int> b{3, 0};   // ブレース：initializer_list → {3, 0}
```

**ブレース `{}` は initializer_list を優先**するので、要素2個のvectorになる。同じ書き方でも括弧の種類で動作が違う。

### 初期化と代入の違い

| | 初期化 | 代入 |
|---|---|---|
| タイミング | オブジェクト**作成時** | オブジェクト**作成後** |
| 呼ばれるもの | **コンストラクタ** | **代入演算子** `operator=` |
| 書く場所 | 宣言と同時 | 宣言の後 |
| `const` 変数 | 可 | **不可** |
| 参照 | 向き先を決める | 参照先を書き換え |

```cpp
int a = 5;     // 初期化（コンストラクタ相当）
a = 10;        // 代入（operator=）

const int c = 5;  // ✅ 初期化OK
c = 10;           // ❌ 代入不可
```

### `=` は初期化でも代入でも使われる

```cpp
int a = 5;      // 初期化
int b;
b = 5;          // 代入

Foo c = a;      // コピー構築（初期化！代入ではない）
Foo d;
d = a;          // コピー代入
```

**見分け方**：**`=` の左側に型名があるかどうか**
- 左に型名あり → 初期化（宣言）
- 左に型名なし → 代入

### Most Vexing Parse

```cpp
Foo a();           // ❌ 関数宣言として解釈される！変数ではない
Foo a;             // ✅ デフォルト構築
Foo a{};           // ✅ 値初期化（推奨）
```

これを回避するためにも **`{}` 初期化を使う** のが現代C++の流儀。

## C#との比較

| 項目 | C# | C++ |
|---|---|---|
| null表現 | `null`（言語組み込み） | `nullptr`（C++11〜） |
| コンストラクタ委譲 | `: this(...)` | `: ClassName(...)` |
| 基底クラスへ | `: base(...)` | `: BaseClassName(...)` |
| new の要否 | 参照型は**必須** | **不要が基本**（スタック確保） |
| 初期化 vs 代入 | 区別は明確 | `=` が両方に現れ紛らわしい |
| ブレース初期化 | なし（collection initializer） | `{}` 初期化が標準 |
| アロケーター注入 | 不可（GC固定） | 可能 |
| most vexing parse | なし | あり（`Foo a();` が関数宣言） |
| `const` 変数 | `readonly` / `const` | `const` |

## 補足

### アロケーター設計の本質（復習）

`std::allocator` は「複数メモリーを確保するもの」ではなく：

1. **型安全な生メモリー確保**（`T*` を返す）
2. **確保と構築を分離できる**
3. **差し替え可能な戦略**（コンテナに独自確保方法を注入）

通常のアプリでは意識不要。ライブラリ実装者・性能最適化向け。

### スタック確保とヒープ確保の使い分け

| 場面 | 選択 |
|---|---|
| スコープ内で使い終わる | **スタック**（`std::vector<int> v;`） |
| 寿命をスコープ超えて延ばす | **ヒープ**（`std::make_unique<T>()`） |
| 可変サイズのオブジェクト | **ヒープ** |
| ポリモーフィック（動的ディスパッチ） | **ヒープ**（基底ポインターで保持） |

迷ったらスタック。本当にヒープが必要な時だけ `make_unique`。

### 委譲コンストラクタの制約

```cpp
// ❌ 委譲と他のメンバー初期化は混ぜられない
vector() : vector(0), first(nullptr) {}

// ❌ 自己ループは未定義動作
Foo() : Foo() {}

// ✅ 委譲だけ
vector() : vector(0) {}

// ✅ メンバー初期化だけ（委譲なし）
vector() : alloc_(), first(nullptr), last(nullptr) {}
```

委譲先が全メンバーを初期化するので二重初期化を防ぐため。

### 初期化のベストプラクティス

1. **必ず初期化する**（未初期化のバグ防止）
2. **`{}` 初期化を優先**（most vexing parse と縮小変換を回避）
3. **`=` の左に型名があれば初期化**と覚える
4. 既存オブジェクトを書き換えるのが**代入**

```cpp
// 推奨スタイル
std::vector<int> v{1, 2, 3};
std::string s{"hello"};
int x{42};
```

### 参照と初期化

```cpp
int a = 5;
int& r = a;        // 初期化：rはaを指す
int b = 10;
r = b;             // 代入：rが指すaに10を入れる（向き先は変わらない）
```

参照は**初期化でしか向き先を決められない**。代入は中身の操作。これが C#の `ref` とは違うところ。

### 構築コストの違い

```cpp
std::vector<int> v1 = {1,2,3};    // 初期化：1回の構築
std::vector<int> v2;              // 初期化：空vector構築
v2 = {1,2,3};                     // 代入：既存を破棄→作り直し
```

**初期化の方が効率的**。可能なら初期化で済ませる。

## 理解度

- [x] `nullptr` と `NULL` の違い（型安全性、オーバーロード解決）
- [x] vectorへのアロケーター指定方法（テンプレート引数/コンストラクタ引数）
- [x] カスタムアロケーターの最小要件（`value_type`, `allocate`, `deallocate`）
- [x] `std::pmr` の多態アロケーター
- [x] 委譲コンストラクタの書き方（`: ClassName(...)`）
- [x] メンバー初期化と委譲の見分け方
- [x] マスターコンストラクタに集約する設計（Funnel Pattern）
- [x] 委譲のメリット（重複排除・修正漏れ防止・不変条件保証）
- [x] 4種類の初期化構文と `{}` 推奨の理由
- [x] ブレース初期化での initializer_list 優先の罠
- [x] 初期化と代入の違い（`const`・参照・効率）
- [x] `=` が初期化でも代入でも使われる混乱と見分け方
- [x] Most Vexing Parse と `{}` による回避

## 次章へ

vectorのコンストラクタと初期化を深掘りしたので、次はおそらく `push_back`/`insert`/`erase` の実装、再確保のロジック、例外安全、あるいはムーブセマンティクスに進むと思われる。
