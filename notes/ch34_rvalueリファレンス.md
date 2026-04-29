# 第34章: rvalueリファレンス

## 要点

### リファレンスとポインターは別物

C++には似て非なる3つの型がある。

```cpp
int  x = 10;
int& r = x;   // リファレンス：x の別名
int* p = &x;  // ポインター：x のアドレスを格納
```

| 項目 | リファレンス `T&` | ポインター `T*` |
|---|---|---|
| 中身 | 別のオブジェクトの**別名** | **アドレスの値** |
| 初期化 | 必須（後で付け替え不可） | 任意、付け替え可 |
| null | 不可 | 可能（`nullptr`） |
| 使い方 | 実体そのものとして扱う | `*p` で間接参照 |
| 再代入 | 元のオブジェクトを書き換える | ポインター自身を別物に向ける |

リファレンスは「既存のオブジェクトに別名を付ける」もの。内部実装はポインターでも、意味論は別物。

### rvalue リファレンスもリファレンスの一種

`T&&` は **rvalue（一時オブジェクトなど）に束縛できるリファレンス**。ポインターではない。

```cpp
int x = 10;
int&  lr = x;               // lvalue リファレンス：lvalue に束縛
int&& rr = 42;              // rvalue リファレンス：rvalue に束縛
int&& rr2 = std::move(x);   // std::move で rvalue 扱いに変換
```

どちらもリファレンスなので：初期化必須、付け替え不可、null 不可、`&`/`*` 不要。

### 何を束縛できるか

| 型 | 束縛できるもの |
|---|---|
| `T&`（lvalue リファレンス） | lvalue のみ |
| `const T&` | lvalue と rvalue どちらも |
| `T&&`（rvalue リファレンス） | rvalue のみ |

この違いで、コピーとムーブを別関数としてオーバーロード可能になる。

```cpp
void f(const std::string& s);   // lvalue を受ける（コピー）
void f(std::string&& s);        // rvalue を受ける（ムーブ）
```

### リファレンスはコピーしない（別名を付けるだけ）

```cpp
int x = 10;
int& r = x;   // 新しい int は作られない
```

- 新しいオブジェクトなし
- 新しいメモリ確保なし
- `x` と `r` は **同じメモリ、同じオブジェクト**

コピー（ディープ／シャロー）とは全く別の概念。コピーは「新しいオブジェクトを作るとき中身をどう持ってくるか」の話、リファレンスは「そもそもオブジェクトを作らず別名を付ける」話。

### 値カテゴリ：lvalue / xvalue / prvalue

C++11 以降、式は3つのカテゴリに分類される。

| カテゴリ | 住所 (identity) | 奪える (movable) | 例 |
|---|---|---|---|
| **lvalue** | あり | × | `x`、`arr[0]`、`obj.member` |
| **xvalue** | あり | ○ | `std::move(x)`、`static_cast<int&&>(x)` |
| **prvalue** | なし | ○ | `42`、`foo()`、`std::string()` |

まとめカテゴリ：
- **glvalue**（住所あり）= lvalue + xvalue
- **rvalue**（奪える）= xvalue + prvalue

### xvalue は「rvalue 化した lvalue」

```cpp
int x = 10;
std::move(x);     // xvalue：住所は x のまま、「奪っていい」というマーカー付き
```

- lvalue：「これから使うから奪うな」
- prvalue：「住所もない一時物、奪っていい」
- xvalue：「住所はあるけど、ユーザーが『もう使わない』と宣言したから奪っていい」

### `static_cast<T&&>(x)` は何もしない

```cpp
int lvalue {};
int&& r_ref = static_cast<int&&>(lvalue);
```

- `lvalue` を rvalue として扱う**型キャスト**のみ
- データは一切動かない
- `r_ref` は `lvalue` と**同じメモリ**を指す
- `lvalue` は 0 のまま、空にならない

`std::move` の中身もこれと同じ：

```cpp
template<typename T>
T&& move(T& x) {
    return static_cast<T&&>(x);   // ただのキャスト
}
```

### 実際に「奪う」のはムーブコンストラクタ

`std::move` は「奪っていい」というマーカーを貼るだけ。実際にポインタを奪って元を空にする処理は、ムーブコンストラクタや代入演算子の中で人間が書く。

```cpp
class MyArray {
    int* data;
public:
    MyArray(MyArray&& other) noexcept {
        data = other.data;       // ← ここで奪う
        other.data = nullptr;    // ← ここで元を空にする
    }
};
```

int などの基本型で何も起きないのは、このムーブコンストラクタが自動生成されても「奪うべきリソース」がないため。

### 名前が付いたら lvalue（最大の罠）

`T&&` の変数自体は式としては lvalue。

```cpp
int x = 10;
int&& y = std::move(x);   // y の型は int&&

int&& z = y;              // ❌ エラー：y は lvalue
int&& w = std::move(y);   // ✅ OK：再度 std::move で xvalue 化
```

ルール：**名前を持つ式は lvalue**。型が `int&&` であっても、変数名として書いた瞬間に値カテゴリは lvalue になる。

```cpp
void f(MyArray&& other) {
    MyArray a = other;              // ← コピーされる！ムーブじゃない
    MyArray b = std::move(other);   // ← これでムーブ
}
```

ムーブコンストラクタの中でも `other` を使い回すときは再度 `std::move` が必要。

### 関数引数の使い分け

```cpp
void f(int x);                  // 値渡し：基本型ならコレ
void f(const T& x);             // const参照：読み取り専用、コピー回避
void f(T& x);                   // 参照：書き換える
void f(T&& x);                  // rvalue参照：所有権を厳格に受け取る
void f(T* x);                   // ポインター：nullを許す
```

実務では9割が `const T&` と `T&` で済む。

| 状況 | 第一選択 |
|---|---|
| 関数内で変更しない | `const T&` |
| 関数内で変更する | `T&` |
| メンバに保存する | 値渡し + `std::move` |
| 基本型（int, double 等） | 値渡し |
| コピー不可型を受ける | `T&&` |
| 迷ったら | `const T&` |

### 値渡し + `std::move` パターン（setter推奨）

```cpp
class User {
    std::string name_;
public:
    void setName(std::string name) {   // 値渡し
        name_ = std::move(name);        // ムーブで格納
    }
};

User u;
u.setName(s);             // コピー→ムーブ
u.setName(std::move(s));  // ムーブ→ムーブ
u.setName("hello");       // 構築→ムーブ
```

lvalue も rvalue も効率的に扱える。sink関数（所有権を受け取る関数）の現代的パターン。

### forwarding reference（ユニバーサル参照）

テンプレート引数の位置で `T&&` と書くと、特別な意味になる。

```cpp
template<typename T>
void f(T&& arg);    // forwarding reference（ユニバーサル参照）

void g(int&& arg);   // ただの rvalue リファレンス（Tが推論される形ではない）
```

forwarding reference は**呼び出し側の値カテゴリを記憶する**：

| 呼び出し | `T` の推論 | `arg` の型 |
|---|---|---|
| `f(x)` (lvalue) | `T = int&` | `int&` |
| `f(std::move(x))` (xvalue) | `T = int` | `int&&` |
| `f(42)` (prvalue) | `T = int` | `int&&` |

背景：**参照畳み込み（reference collapsing）**

```
T&  &&  →  T&
T&& &   →  T&
T&  &   →  T&
T&& &&  →  T&&
```

`&` が1つでも混ざると `&`、両方 `&&` のときだけ `&&`。

### `std::forward`：値カテゴリを保って転送

```cpp
template<typename T>
void wrapper(T&& arg) {
    real_function(std::forward<T>(arg));
}
```

- `arg` が lvalue で来たなら → lvalue として転送
- `arg` が rvalue で来たなら → rvalue として転送

実装：

```cpp
template<typename T>
T&& forward(std::remove_reference_t<T>& arg) noexcept {
    return static_cast<T&&>(arg);
}
```

参照畳み込みを利用した条件付きキャスト。

### `std::move` と `std::forward` の違い

| 目的 | 使うもの |
|---|---|
| 無条件に rvalue にキャスト | `std::move` |
| 元の値カテゴリに応じて転送（保つ） | `std::forward` |

- `std::move`：「これは rvalue だ」と断言
- `std::forward`：「元のカテゴリに戻す」

### 完全転送の実用例

```cpp
template<typename T, typename... Args>
std::unique_ptr<T> make_unique(Args&&... args) {
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}

std::string s = "hello";
auto p1 = make_unique<Foo>(s);              // lvalue → Foo(const string&)
auto p2 = make_unique<Foo>(std::move(s));   // rvalue → Foo(string&&)
auto p3 = make_unique<Foo>("world");        // prvalue → Foo(const char*)
```

1つの関数で「コピーとムーブの両方を最適に処理」できる。

### `std::forward` が必要な場面は限定的

- ライブラリ・フレームワークを書くとき
- 汎用的なラッパーやファクトリ関数を書くとき

普通のアプリケーションコードでは、標準ライブラリが内部で使ってくれているので恩恵は受けるが、自分で書く機会は少ない。

## C#との比較

| 項目 | C# | C++ |
|---|---|---|
| リファレンス | 参照型の変数（実質ポインター） | `T&`：別名、`T&&`：rvalue 用 |
| ポインター | `unsafe` の `T*` のみ | 通常の `T*` |
| rvalue リファレンス | 存在しない | `T&&` |
| 値カテゴリ | 区別なし | lvalue / xvalue / prvalue |
| 参照渡し | `ref` / `out` キーワード | `T&` / `const T&` |
| 完全転送 | 存在しない | `std::forward` |
| 引数渡しの選択肢 | 値渡し / ref / out の3つ | 値 / 参照 / const参照 / rvalue参照 / ポインター |

C#は「参照のコピー」が中心で、ムーブや完全転送の概念がない。C++は値カテゴリを型システムに取り込むことで、コピーとムーブを使い分けられる代わりに複雑になっている。

## 補足

### `int&&` を関数引数に使う意味

基本型（`int` など）では `int&&` と値渡しで実用上の差はない。重い型でこそ意味がある。

```cpp
// rvalue しか受けないことを強制
void set(std::vector<int>&& v);

std::vector<int> v = {1,2,3};
set(v);              // ❌ コンパイルエラー
set(std::move(v));   // OK（呼び出し側に std::move を強制できる）
```

### ムーブ後の名前付き変数の扱い

```cpp
MyArray(MyArray&& other) noexcept {
    // other は型 MyArray&& だが、名前があるので式としては lvalue
    MyArray m = other;              // コピー
    MyArray m2 = std::move(other);  // ムーブ
}
```

ムーブコンストラクタの中で `other` を複数回使うとき、どこでムーブを発動させるか意識する必要がある。

### 自作クラスは std を使うのが基本

生リソースを持つと Rule of Five 全部書く羽目になる。現代C++では std の型で組み立て、Rule of Zero を目指す。

```cpp
// ❌ 古典的（6関数書く）
class Buffer {
    int* data;
    size_t size;
    // コピー・ムーブ・デストラクタ全部必要
};

// ✅ 現代的（何も書かない）
class Buffer {
    std::vector<int> data;
};
```

`std::string` / `std::vector` / `std::unique_ptr` / `std::shared_ptr` が4大ヒーロー。

### `auto&&` も forwarding reference

```cpp
auto&& a = x;                  // a の型は int&（xは lvalue）
auto&& b = std::move(x);       // b の型は int&&
auto&& c = 42;                 // c の型は int&&
```

range-based for などでも使われる：

```cpp
for (auto&& e : container) {   // 要素が lvalue でも rvalue でも受ける
    // ...
}
```

### `std::forward` を間違えて使わないために

forwarding reference は以下の形のみ：

```cpp
template<typename T>
void f(T&& arg);          // ✅ forwarding reference

void g(int&& arg);        // ❌ 普通の rvalue リファレンス

template<typename T>
void h(std::vector<T>&& arg);  // ❌ 普通の rvalue リファレンス
                               //（T&& の形ではない）

auto&& x = something;     // ✅ forwarding reference
```

普通の rvalue リファレンス引数に `std::forward` を使うのは無意味（`std::move` を使う）。

### 値カテゴリの実用的な覚え方

細かい分類は実務では深追いしない。以下で十分：

1. 変数名を書いたら **lvalue**
2. `std::move(x)` と書いたら **rvalue（xvalue）**
3. 一時オブジェクトやリテラルは **rvalue（prvalue）**
4. xvalue と prvalue の違いは住所の有無だけ、ムーブ文脈では同じ扱い

### const T& は万能だが万能ではない

`const T&` は lvalue も rvalue も受けられて便利だが：
- 中身を書き換えられない
- ムーブで最適化できない

所有権を取る sink 関数では、**値渡し + std::move** か **T&&** を選ぶ。

```cpp
// const T& だとムーブできない
void push(const std::string& s) {
    data_.push_back(s);   // 常にコピー
}

// 値渡し + std::move なら柔軟
void push(std::string s) {
    data_.push_back(std::move(s));  // lvalue なら1コピー、rvalue なら0コピー
}
```

## 理解度

- [x] リファレンスとポインターの違い（別名 vs アドレス）
- [x] `T&` / `T&&` / `T*` の使い分け
- [x] リファレンスはコピーしない（別名のみ）
- [x] 値カテゴリ：lvalue / xvalue / prvalue の分類
- [x] xvalue は「rvalue 化した lvalue」
- [x] `static_cast<T&&>` / `std::move` は型キャストのみで何も動かさない
- [x] 実際に奪うのはムーブコンストラクタの中
- [x] 「名前が付いたら lvalue」ルールと再度の `std::move`
- [x] 関数引数の使い分け（`const T&`、`T&`、`T&&`、値渡し）
- [x] 値渡し + `std::move` による sink 関数パターン
- [x] forwarding reference（ユニバーサル参照）の仕組み
- [x] 参照畳み込みのルール
- [x] `std::forward` の役割と実装
- [x] `std::move` と `std::forward` の違い（無条件 vs 条件付き）

## 次章へ

rvalue リファレンスと値カテゴリを押さえたので、次は **継承・ポリモーフィズム**（`virtual`、派生クラス、仮想デストラクタ、`override` など）に進むと思われる。C# の OOP と直接対応するトピックで、違いが明確に出る領域。
