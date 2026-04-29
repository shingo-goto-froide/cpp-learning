# 第24章: arrayの実装

## 要点

### 型エイリアス（using）

- `using` で型に別名をつけられる
- `typedef` より読みやすいので、現代C++ではこちらが主流

```cpp
using number = int;
number x = 123;  // int x = 123; と同じ
```

- クラス内で型情報を公開するのが標準ライブラリのお約束

```cpp
template <typename T, std::size_t N>
struct array {
    using value_type = T;          // T の別名
    using reference  = T&;         // T& の別名
    using size_type  = std::size_t; // std::size_t の別名
};

array<int, 5>::value_type x;  // int x; と同じ
```

### 非型テンプレートパラメータ

- テンプレートには型だけでなく**値**も渡せる

```cpp
template <typename T, std::size_t N>
//        ^^^^^^^^^^  ^^^^^^^^^^^^^
//        型を渡す     値を渡す
struct array {
    T storage[N];  // T型の要素をN個持つ配列
};

array<int, 5> a;    // T=int(型), N=5(値)
```

- `std::size_t N` は「`std::size_t` 型の値を受け取る」という意味
- `int N` でも動くが、負の値が渡せてしまうので `std::size_t` が適切
- C#のジェネリクスは**型しか渡せない**ので、この機能はC++特有

### C++の配列宣言

- `[]` は変数名の後ろにつく（C#と逆）

```cpp
// C++
int storage[5];   // OK
int[] storage;     // エラー

// C#
int[] storage;     // OK
```

### テンプレート関数で任意の array を受け取る

- `std::array<int, 3>` と `std::array<int, 5>` は**完全に別の型**
- テンプレートなしでは型とサイズの組み合わせごとに関数を書く必要がある

```cpp
// テンプレートなし → 無限に増える
void print(std::array<int, 3> & c) { /* ... */ }
void print(std::array<int, 5> & c) { /* ... */ }

// テンプレートあり → 1つで全部対応
template <typename Array>
void print(Array & c) {
    for (std::size_t i = 0; i != c.size(); ++i) {
        std::cout << c[i];
    }
}
```

- `template <typename T, std::size_t N>` で `std::array` だけに限定もできる

```cpp
template <typename T, std::size_t N>
void print(std::array<T, N> & c) { /* ... */ }
// std::array 以外を渡すとエラー
```

### const メンバ関数

- `const` オブジェクトは **`const` がついたメンバ関数しか呼べない**

```cpp
struct Dog {
    int age = 3;
    void bark() { std::cout << "wan"; }            // const なし
    void sit() const { std::cout << "osuwari"; }   // const あり
};

const Dog d;
d.bark();  // エラー！const なし関数は呼べない
d.sit();   // OK
d.age = 5; // エラー！メンバ変数も変更できない
```

- `const` メンバ関数は「この関数はメンバ変数を変更しません」という約束
- `const` オブジェクトはどうやっても変更できない

```cpp
// print が const & で受け取る場合
template <typename Container>
void print(Container const & c) {
    c.size();  // size() に const がないと → エラー
    c[i];      // operator[] に const がないと → エラー
}
```

- 自作 array の `size()` や `operator[]` にも `const` 版が必要

### 宣言と定義の分離

- クラスの中に**宣言だけ**置き、定義はクラスの外に書ける

```cpp
// 宣言（クラス内）
struct Dog {
    void bark();
};

// 定義（クラスの外）
void Dog::bark() {
    std::cout << "wan";
}
```

- `Dog::bark` の `::` で「Dog に属する関数」と示す
- 小さいクラスならクラス内に直接書いてもOK
- 大きいクラスでは宣言と定義を分けると一覧性が高くなる

### ヘッダーファイルとソースファイル

- 実務では**ヘッダー（`.h`）とソース（`.cpp`）をセットで作る**のが基本

```cpp
// dog.h（ヘッダー — 宣言）
struct Dog {
    void bark();
    void sit();
    int age;
};

// dog.cpp（ソース — 定義）
#include "dog.h"

void Dog::bark() { /* ... */ }
void Dog::sit() { /* ... */ }
```

- ヘッダーが必要な理由: 他のファイルから使うとき、クラスの存在を教えるため
- 1ファイルで完結するなら、定義だけで十分（ヘッダー不要）
- C#はクラスごとに `.cs` 1ファイルだが、C++はクラスごとに `.h` + `.cpp` の2ファイル

## C#との比較

| 項目 | C# | C++ |
|------|-----|------|
| 型エイリアス | `using number = int;` | `using number = int;`（同じ構文） |
| ジェネリクスに値を渡す | 不可 | `std::size_t N` で可能 |
| 配列宣言 | `int[] a` | `int a[5]`（`[]` が後ろ） |
| const メンバ関数 | なし（`readonly` で部分的に対応） | メンバ関数に `const` をつける |
| ファイル構成 | `.cs` 1ファイル | `.h` + `.cpp` の2ファイル |
| 定義の場所 | クラス内のみ | クラス内でも外でもOK |

## 補足

### const メンバ関数の使いどころ

- 実務で一番多いのは**関数の引数で `const &` を受け取るケース**
- クラスのインスタンス自体を `const` にすることは比較的少ない
- メンバ関数に `const` をつけておくと、`const` 参照で渡されても呼べるので、つけられるなら基本つけておくのがよい

### concept（C++20）

- テンプレートの弱点（中身を見ないと何を渡せるかわからない）を解決する仕組み
- C#の `where` 制約に近い役割

```cpp
template <typename T>
concept HasSizeAndIndex = requires(T c, std::size_t i) {
    c.size();
    c[i];
};

void print(HasSizeAndIndex auto & c) { /* ... */ }
```

## 理解度

- [x] `using` による型エイリアスの使い方
- [x] テンプレートに型だけでなく値も渡せる（非型テンプレートパラメータ）
- [x] `std::array<int,3>` と `std::array<int,5>` は別の型
- [x] `const` オブジェクトは `const` メンバ関数しか呼べない
- [x] `const` メンバ関数内ではメンバ変数を変更できない
- [x] 宣言と定義を分離できる（`Dog::bark()` の書き方）
- [x] ヘッダーファイルとソースファイルの役割と使い分け
