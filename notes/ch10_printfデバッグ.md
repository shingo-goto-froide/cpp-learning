# 第10章: printfデバッグ

## 要点

### printfデバッグとは

- `std::cout`や`std::cerr`で値を出力して動作を確認する手法
- C#の`Console.WriteLine()`デバッグと同じ
- 専用のデバッグ関数があるわけではなく、ただ出力しているだけ

```cpp
int x = 42;
std::cout << "debug: x = " << x << std::endl;
```

### よく使うパターン

| 目的 | コード |
|---|---|
| 変数の値 | `std::cout << "x=" << x << std::endl;` |
| 通過確認 | `std::cout << "here!" << std::endl;` |
| 条件分岐の確認 | `std::cout << "if側に入った" << std::endl;` |

### ループのデバッグ出力

- ソートの各ステップの状態を出力して過程を追跡する

```cpp
for (std::size_t head = 0; head != size; ++head)
{
    std::cout << "debug: head = "s << head << ", v= { "s;
    for (std::size_t i = 0; i != v.size(); ++i)
    {
        std::cout << v.at(i) << " "s;
    }
    std::cout << "}\n"s;
}
```

- `<<`は連結演算子のように使い、左から順に出力をつなげている
- C#の文字列補間（`$"x = {x}"`）に相当する機能はなく、`<<`でつなげるスタイル

### std::cerr — 標準エラー出力

- エラーやデバッグ用の出力ストリーム
- `std::cout`と使い方は同じだが、出力先が別

```cpp
std::cout << "結果: 42" << std::endl;       // 標準出力
std::cerr << "debug: x = 10" << std::endl;  // 標準エラー出力
```

### フラッシュ（flush）

- プログラムの出力はすぐ画面に表示されず、バッファ（一時的な溜め場）に貯まる
- フラッシュ = バッファの中身を画面に送り出すこと

```cpp
std::cout << "hello" << "\n";       // 改行のみ（バッファに残るかも）
std::cout << "hello" << std::endl;  // 改行 + フラッシュ（確実に表示）
```

| | フラッシュ | クラッシュ時 |
|---|---|---|
| `std::cout` + `"\n"` | されない場合がある | 表示されない可能性 |
| `std::cout` + `std::endl` | 毎回される | 表示される |
| `std::cerr` | 常にされる | 確実に表示される |

- デバッグ時は`std::cerr`か`std::endl`を使うと安全

### リダイレクト — プログラムとファイルをつなぐ

```bash
./program > output.txt      # coutをファイルへ（上書き）
./program >> output.txt     # coutをファイルへ（追記）
./program < input.txt       # ファイルからcinへ
./program 2> error.txt      # cerrをファイルへ
./program > out.txt 2> err.txt  # 両方別々のファイルへ
```

- リダイレクト時、`std::cerr`はターミナルに残る

```bash
./program > result.txt
```

| | 出力先 |
|---|---|
| `std::cout` | `result.txt` |
| `std::cerr` | ターミナル（画面） |

- ファイルディスクリプタ（出力先の番号）:

| 番号 | 名前 | C++ |
|---|---|---|
| 0 | 標準入力 | `std::cin` |
| 1 | 標準出力 | `std::cout` |
| 2 | 標準エラー出力 | `std::cerr` |

### パイプ（`|`）— プログラムとプログラムをつなぐ

- 前のプログラムの`cout`を次のプログラムの`cin`につなげる

```bash
ls | grep ".cpp" | wc -l
```

```
ls          →  grep ".cpp"  →  wc -l
全ファイル出力    .cppだけ残す     行数を数える
```

- すべてのコマンドは同じ構造: `cin → [処理] → cout`

| コマンド | 処理内容 |
|---|---|
| `ls` | ファイル一覧をcoutに出す |
| `grep` | cinから受けて、一致する行だけcoutに出す |
| `wc -l` | cinから受けて、行数をcoutに出す |

- 自作プログラムもパイプでつなげられる

```cpp
// double.cpp — 入力を2倍にして出力
int main() {
    int x{};
    while (std::cin >> x) {
        std::cout << x * 2 << "\n";
    }
}
```

```bash
echo "3 5 7" | ./double
# 出力: 6 10 14
```

- プログラム側はパイプかキーボードかを意識する必要がない（どちらも`std::cin`から読める）

### シェルのコマンド

| 種類 | 例 | 場所 |
|---|---|---|
| シェル組み込み | `echo`, `cd`, `export` | シェル自体に内蔵 |
| 外部コマンド | `ls`, `grep`, `wc` | 独立したプログラムとして存在 |

- `echo`は文字列をそのまま`cout`に出力するコマンド

```bash
echo "hello"    # 出力: hello
```

## C#との比較

| 項目 | C# | C++ |
|------|-----|------|
| デバッグ出力 | `Console.WriteLine()` | `std::cout <<` / `std::cerr <<` |
| エラー出力 | `Console.Error.WriteLine()` | `std::cerr <<` |
| フラッシュ | 自動（意識不要） | `std::endl`か`std::cerr`で明示 |
| 文字列補間 | `$"x = {x}"` | なし（`<<`でつなげる） |
| リダイレクト/パイプ | `ProcessStartInfo`で設定 | シェルでコマンド1つ |

## 補足

### printfデバッグにstd::cerrを使う利点

- プログラムの本来の出力（cout）とデバッグ出力（cerr）が混ざらない
- リダイレクトやパイプ使用時もデバッグ情報がターミナルで見える
- 常にフラッシュされるので、クラッシュ直前の出力も確実に表示される

### Unixの設計思想

- 「小さなプログラムを組み合わせて大きな処理を作る」という考え方
- 各プログラムは`cin`から読んで`cout`に出す、というシンプルな構造
- パイプでつなげることで柔軟な処理が可能

## 理解度

- [x] printfデバッグの基本的な使い方
- [x] `<<`による出力の連結
- [x] std::coutとstd::cerrの違い
- [x] フラッシュの意味（バッファと即時出力）
- [x] std::endlと"\n"の違い
- [x] リダイレクト（>、<、2>）の使い方
- [x] パイプ（|）の仕組み
- [x] 自作プログラムのパイプ接続
- [x] シェル組み込みコマンドと外部コマンドの違い
