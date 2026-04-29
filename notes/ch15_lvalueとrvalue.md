# 第15章: lvalueとrvalue

## 要点

### 値カテゴリとは

- C++ではすべての式（expression）に**値カテゴリ**がある
- 大きく**lvalue**と**rvalue**に分かれる

```cpp
int x = 42;

x;      // lvalue — メモリ上に実体がある
42;     // rvalue — 一時的な値
x + 1;  // rvalue — 計算結果は一時的
```

### lvalue と rvalue の名前の由来

- **l**eft value（左辺値）と **r**ight value（右辺値）
- 代入の左辺・右辺に置けるかどうかが元々の由来

```cpp
x = 42;
// x  → 左辺(left)に置ける  → lvalue
// 42 → 右辺(right)にしか置けない → rvalue
```

- ただし現代C++では「左辺に置けるか」だけでは説明しきれないケースもある

### 判別方法: アドレスが取れるか

- `&`（アドレス演算子）が使えるかどうかで判別できる

```cpp
int x = 42;

&x;     // OK — lvalueだからアドレスが取れる
&42;    // エラー — rvalueだからアドレスが取れない
&(x+1); // エラー — rvalueだからアドレスが取れない
```

### const lvalue参照

- `const T&` は lvalue も rvalue も受け取れる
- 関数の引数で最もよく使うパターン

```cpp
void foo(std::string& s);        // lvalue参照 — lvalueしか受け取れない
void foo(const std::string& s);  // const lvalue参照 — 両方受け取れる
```

```cpp
std::string name = "hello";

foo(name);            // どちらもOK
foo("temporary");     // constありだけOK（rvalueを受け取れる）
foo(name + "!");      // constありだけOK（rvalueを受け取れる）
```

### 引数の渡し方の使い分け

```cpp
// ① 小さい型（int, double等）→ 値渡し
void foo(int n);

// ② 大きい型で読むだけ → const参照渡し（最頻出）
void foo(const std::string& s);
void foo(const std::vector<int>& v);

// ③ 中身を変更したい → 参照渡し
void foo(std::string& s);
```

- ②の `const T&` が実務で圧倒的に多い
- 「大きいデータをコピーせず、かつ変更しない」場面が最も多いため

## C#との比較

| 項目 | C# | C++ |
|------|-----|------|
| 値カテゴリ | 意識する必要がほぼない | すべての式がlvalue/rvalueに分類される |
| 参照型の引数 | コピーされない（ポインタ渡し） | 値渡し（コピーが発生する） |
| コピー回避 | 不要（参照型は元々参照） | `const T&` で明示的に回避する |
| `ref`キーワード | 値型の参照渡し | C++のlvalue参照（`T&`）に近い |
| `in`キーワード | readonly参照渡し | `const T&` に近い |
| `string`の渡し方 | `void Foo(string s)` — コピーなし | `void foo(const std::string& s)` — `const&`が必要 |

- C#では参照型/値型を言語が分けてくれるのでコピーコストを意識しない
- C++では`std::string`等も値型なので、**自分でコピーコストを管理する**必要がある

## 補足

### なぜC++では値カテゴリが重要か

- C++では参照（`&`）やムーブセマンティクス（`&&`）の理解に直結する
- lvalue/rvalueの区別は後の章で学ぶ**ムーブ**の基礎になる

### const参照がrvalueも受け取れる理由

- `const`なので変更しない → 一時的な値（rvalue）を束縛しても安全
- 非constの`T&`は変更できてしまうため、一時的な値を束縛させると危険

## 理解度

- [x] lvalue/rvalueの概念（メモリに実体があるかどうか）
- [x] 名前の由来（left/right）と現代での判別方法（アドレスが取れるか）
- [x] const lvalue参照が両方受け取れること
- [x] 引数の渡し方の使い分け（値渡し / const参照 / 参照）
- [x] C#との違い（コピーコストの管理が必要）
