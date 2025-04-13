# はじめに

雑個人メモ。正確でない箇所あり。

# HTML

## タグ・要素・コンテンツカテゴリ

- ブロック要素:この要素は横幅いっぱいの領域を持つので、要素の前後には自動的に改行が入ることになります。

  - 要素
    ```
    <div>
    <dl>
    <form>
    <h1>-<h6>
    <hr>
    <ol>
    <p>
    <table>
    <ul>
    ```

- インライン要素:この要素は行の一部として扱われるので、要素の前後には改行は入りません。

  - 要素
    ```
    <a>
    <br>
    <button>
    <font>
    <iframe>
    <img>
    <input>
    <label>
    <script>
    <select>
    <span>
    <strong>
    <textarea>
    ```

# CSS

## flex

各要素の意味合い

- align: 要素の並び方向の交差方向での配置方法を設定 (通常は縦)
- justify: 要素の並び方向での配置方法を設定 (通常は横)

- content：ボックス全体に対して
- items：ボックス内にあるアイテム全てに対して
- self：設定されたアイテムに対して (flexbox 内では使用できない)

- 要素をどちらかに寄せたい
  →aligh-items:縦,justify-items:横
- 要素を等間隔で配置したい
  →aligh-contents:縦,justify-contents:横

### css 詳細

- align-items: flex コンテナ内の要素全体に対して設定する(縦の位置、交差軸)
  すべての直接の子要素に集合として align-self の値を設定します。
  コンテナ内の縦方向(交差軸方向)に対する位置決め
  デフォルトだと、縦方向(主軸は横なので)、flex-direction:column の場合は横方向になる
  https://developer.mozilla.org/ja/docs/Web/CSS/align-items

- justify-items: flex コンテナ内の要素全体に対して設定する(横の位置、主軸)
  コンテナ内の横方向(主軸方向)に対する位置決め
  デフォルトだと、横方向、flex-direction:column の場合は縦方向になる

- align-content: flex コンテナ内の要素全体に対して設定する(横の位置、主軸)
  コンテナ内の横方向(主軸方向)に対する位置決め
  デフォルトだと、横方向、flex-direction:column の場合は縦方向になる

- justify-content: 横方向の要素の間隔周りを指定(横方向、主軸)

  - flex-start : 行頭寄せ(通常は左寄せ)
  - flex-end : 行末寄せ(通常右寄せ)
  - center: 中央寄せ
  - space-between : アイテム間をスペースで均等に割当

- align-self: flex コンテナ内の要素に対して個別に追加設定する
  - auto（初期値）: 親要素の align-items の値に従う
  - flex-start : 親要素の始端に配置（左 or 上）
  - flex-end : 親要素の終端に配置（右 or 下）
  - center : 親要素の中央に配置
  - baseline : flex アイテムのベースライン（テキストの下端）に配置
  - stretch : 親要素の横幅に合わせて flex アイテムを伸縮

# TypeScript

- テンプレートリテラル型 `${T}`
  文字列型の一種、${}の中に式ではなく型が入る`Hello ${string}`
  例.
  fuction makeKey <T extends string >(userName : T) {
    return `user:${userName}` as const
  }

- ユニオン型

  - A | B extends Y ? S : T → (A extends Y ? Sa : Ta) | (B extends Y ? Sb : Tb)、ユニオン分配 (union distribution)
    例.
    type IsString<T> = T extends string ? true : false;
    type C = IsString<string | number>; //boolean

- オブジェクト型

  - {[key:string] : T}、インデックス型: key を指定しない
    type T = {[key: string]: string | number};

- typeof 値 :値から型を抽出できる、オブジェクトからは対応した型を抽出できる
  例.
  const point = { x: 135, y: 35 };
  type Point = typeof point; //{x: number;y: number;}

- keyof T : (obj → key(union))オブジェクト型からプロパティ名の型を取得(だいたいリテラル型のユニオンになる)

  - 例 1
    type Human = { name : string ; age : number ;}
    type HumanKeys = keyof Human // "name" | "age"型
  - 例 2、keyof typeof オブジェクト(オブジェクトから一気に key のユニオンが取れる)
    const mmConversionTable = { mm : 1 , m : 1e3 , km : 1e6 }
    type x = keyof typeof mmConversionTable // "mm" | "m" | "km"型
  - 例 3. K extends keyof T : オブジェクト型の key のユニオン型を指定
    function get<T , K extends keyof T>(obj : T , key : K) :T[K] { return obj[key] }

- インデックスアクセス型:オブジェクト型["プロパティ名"]・配列型[number];

  - 基本

    - T["key1" | "key2"]・T[1 | 2]、アクセスには Union 型も使え、返り値はユニオンそれぞれを満たすユニオン型が返ってくる
      例.
      type Person = { name: string; age: number };
      type T = Person["name" | "age"]; // string | number
      例 2.T["length"] : 配列の、T['length'] はその 長さの型 を取り出せる
      type First<T extends any[]> = T['length'] extends 0 ? never : T[0]

    - T[keyof T] : (obj → value(union))keyof 型演算子と組み合わせると、オブジェクトの全プロパティの型がユニオン型で得られる
      型オブジェクト T に対して、keyof T でそれぞれ取り出すイメージ
    - key を得たい keyof T
    - value を得たい T[keyof T]

    type Foo = { a: number; b: string; c: boolean };
    type T = Foo[keyof Foo]; // string | number | boolean

  - T[number] : (arr → value) 配列型から要素の型を取り出す
    const array = [null, "a", "b"];
    type T = (typeof array)[number]; // string | null

  - T[K] : (obj → value)型の value の値を取得(lookup 型、オブジェクトの value アクセスの型版)
    type Human = { type : "human" ; name : string ; age : number ;}
    Human["age"] //number 型

  - { [P in K ] : T} : 新たな obj 型を作成、主に文字列リテラル型のユニオン型から新しいオブジェクトの型を作成する
    例 1.
    type Fruit = "apple" | "orange" | "strawberry"
    type FruitNumbers = { [P in Fruit] : number } // {apple : number ; orange : number ; strawberry : number }
    例 2.
    type MyReadonly<T> = { readonly [K in keyof T] : T[K] }

  - X extends Y ? S : T、条件型
    extends で型の true/false を表現するイメージ
    例.
    type First<T extends any[]> = T extends [] ? never : T[0]

  - T extends infer S ? X : Y、条件(T extends S の S のとこ)に infer S と書くと、S に補足された型を X の部分で再利用可能になります。

        例.※`<S extends string>`は markdown の関係で``で囲っている

    type ExtractHelloedPart`<S extends string>`= S extends`Hello, ${infer P}!` ? P : unknown;

- ユーティリティ型

  - Required<T>:オブジェクトのプロパティを必須にする
    type Person = {surname: string; middleName?: string; givenName: string; };
    type RequiredPerson = Required<Person>; // {surname: string; middleName: string; givenName: string;}

  - Partial<T> : オブジェクトの型 T のすべてのプロパティをオプションプロパティにする
    type Person = {surname: string; middleName?: string; givenName: string; };
    type PartialPerson = Partial<Person>; // {surname?: string | undefined; middleName?: string | undefined; givenName?: string | undefined; };

  - Pick<T,K>型 : オブジェクト T 型の一部を取り出す, K にはプロパティキーを指定する
    type T = Pick<{name : string , age : number} , "age"> //{age : number}

  - NonNullable<T> : null と undefined の型を除く、Exclude<T , null | undefined>と同様
    type String1 = NonNullable<string>; //string
    type String2 = NonNullable<string | null>; // string
    type String3 = NonNullable<string | undefined>; // string
    type String4 = NonNullable<string | null | undefined>; //string

  - Record<Keys, Type> : key,value の型を指定したオブジェクトの型を作る(特に keys を特定の key 名に限定するときとかに使う)

  例 1.キーが string で値が number のインデックス型を定義する。
  type StringNumber = Record<string, number>;
  const value: StringNumber = { a: 1, b: 2, c: 3 };
  例 2.キーが firstName、middleName、familyName で、値が文字列になるオブジェクトの型を定義する。
  type Person = Record<"firstName" | "middleName" | "lastName", string>;
  const person: Person = { firstName: "Robert", middleName: "Cecil", lastName: "Martin"};

  - ReturnType<T> : 関数の戻り値の型を取得する
    例 1.
    type ReturnType1 = ReturnType<() => string>; //string
    type ReturnType2 = ReturnType<(arg: string) => string | number>; // string | number
    type ReturnType3 = ReturnType<() => never>; // never
    例 2. ReturnType<typeof func> : typeof func で関数の型を取得して、一気に返り値の型まで取得する

# Vue

# Go

## 備忘録
- package mainが先頭に必要
- 型
  - 型はJSやPythonと同じように変数の後に宣言
- ポインタ、
  - & オペレータは、そのオペランド( operand )へのポインタを引き出します。
  - `*` オペレータは、ポインタの指す先の変数を示します。
  ```go
  i := 42
  p = &i
  fmt.Println(*p) // ポインタpを通してiから値を読みだす
  *p = 21         // ポインタpを通してiへ値を代入する
  ```
- collectionや構造体の作り方→型{初期値}
  - 配列、[]int{1,2,3}、make([]int,0,5)
  - map、map[string]int{"age":30}、make(map[string]int)
  - 構造体、Struct{Name: "Alice",Age: 25}
  - 構造体のメソッド
  ```go
  // ポインタレシーバ func (v *T) name(){}
  func (v *Vertex) Scale(f float64) {
    v.X = v.X * f
    v.Y = v.Y * f
  }
  ```
- 文
  - if文、`if condition {} else if {} else {}`
    conditionで()いらない、;で事前に変数定義できる
    - `if y:= xx; cond {}`

  - for文、`i,v := range xxx`
    - `for i,item := range xxx {}`
    - `for i := 0; i < 10; i++ {}`
    - `for condition {}`
- エラー
  - errors.Newでエラーオブジェクトを定義
  ```go
  func divide(a, b float64) (float64, error) {
      if b == 0 {
          return 0, errors.New("invalid input")
      }
      return a / b, nil
  }
  ```

## CLI

- go mod init xxx、go modファイルの作成、モジュール初期化
- go build、ビルドコマンドで、依存モジュールを自動インストールする
- go list -m all、現在の依存モジュールを表示する
- go get xxx、パッケージDL
例.
go get github.com/gin-gonic/gin
- go mod tidy、使われていない依存モジュールを削除する
- go install xx : go.modの書き換え無しにinstall
  https://pkg.go.dev/cmd/go
  例. go install golang.org/x/website/tour@latest
- go run xxx.mod : ファイル実行

## パッケージ
- Goのプログラムは、パッケージ( package )で構成されます。
プログラムは main パッケージから開始されます。
- 規約で、パッケージ名はインポートパスの最後の要素と同じ名前になります。
例えば、インポートパスが "math/rand" のパッケージは、 package rand ステートメントで始まるファイル群で構成します。
例.
  ```go
  import (
    "fmt"
    "math/rand"
  )

  func main() {
    fmt.Println("My favorite number is", rand.Intn(10))
  }
  ```
- Goでは、最初の文字が大文字で始まる名前は、外部のパッケージから参照できるエクスポート（公開）された名前( exported name )です。
例.math.Pi は math パッケージでエクスポートされており、math.piはエラーになります。

## 型
- Go言語の基本型(組み込み型)
  ```go
  bool
  string
  int  int8  int16  int32  int64
  uint uint8 uint16 uint32 uint64 uintptr
  byte // uint8 の別名
  rune // int32 の別名// Unicode のコードポイントを表す
  float32 float64
  complex64 complex128
  ```

- 複数変数の型
  例.複数の変数の最後に型を書くことで、変数のリストを宣言できる
  ```go
  var c, python, java bool
  ```
- 型変換、型(x)
  変数 v 、型 T があった場合、 T(v) は、変数 v を T 型へ変換します。
  例.
  ```go
  var i int = 42
  var f float64 = float64(i)
  var u uint = uint(f)
  ```
- 関数の型、func(val 型) 型
  例.
  ```go
  func fibonacci() func() int {
    n, n1 := 0, 1
    return func() int {
      v := n
      n, n1 = n1, n+n1
      return v
    }
  }
  ```

## interface
- interface(インタフェース)型は、メソッドのシグニチャの集まりで定義します。
  そのメソッドの集まりを実装した値を、interface型の変数へ持たせることができます。
  ```go
  type Abser interface {
    Abs() float64
  }
  ```
- 型にメソッドを実装していくことによって、インタフェースを実装(満た)します。(実装＝メソッドを持っている)
Goで「型がインターフェースを実装する」という言い方は、その型がインターフェースが要求するメソッドを全部持っていれば、自動的に“実装したことになる” = 「明示的に implements しない」代わりに、「構造的に合っていれば、それでOK」というルール
  以下で、MyFloatの型がAbsメソッドを持っていれば、floatのインターフェイスを実装しているとみなされる
  ```go
  type MyFloat float64

  func (f MyFloat) Abs() float64 {
    if f < 0 {
      return float64(-f)
    }
    return float64(f)
  }
  ```
- ゼロ個のメソッドを指定されたインターフェース型は、 空のインターフェース `interface{}`
  空のインターフェースは、任意の型の値を保持できます。 (全ての型は、少なくともゼロ個のメソッドを実装しています。)
	空のインターフェースは、未知の型の値を扱うコードで使用されます。
  例えば、 fmt.Print は interface{} 型の任意の数の引数を受け取ります。
	```go
  var i interface{}
	describe(i)

  func describe(i interface{}) {
    fmt.Printf("(%v, %T)\n", i, i)
  }
  ```

## 型アサーション
- `t, ok := i.(T)`
  - 型アサーション は、インターフェースの値の基になる具体的な値を利用する手段を提供します。
	この文は、インターフェースの値 i が具体的な型 T を保持し、基になる T の値を変数 t に代入することを主張します。
	- インターフェースの値が特定の型を保持しているかどうかを テスト するために、型アサーションは2つの値(基になる値とアサーションが成功したかどうかを報告するブール値)を返すことができます。

## 変数・定数
- 変数 := xx
・var 宣言の代わりに、短い := の代入文を使い、暗黙的な型宣言ができます。
なお、関数の外では、キーワードではじまる宣言( var, func, など)が必要で、 := での暗黙的な宣言は利用できません。
- 定数 const x = xxx
定数は、 const キーワードを使って変数と同じように宣言。
定数は、文字(character)、文字列(string)、boolean、数値(numeric)のみで使えます。
なお、定数は := を使って宣言できません。

## ポインタ
- 変数 T のポインタ、*T 型（Tのポインタ型）
変数 T のポインタは、 *T 型でゼロ値は nil です。
```go
var p *int
```
- & オペレータは、そのオペランド( operand )へのポインタを引き出します。
- `*` オペレータは、ポインタの指す先の変数を示します。
これは "dereferencing" または "indirecting" としてよく知られています。
  ```go
  i := 42
  p = &i
  fmt.Println(*p) // ポインタpを通してiから値を読みだす
  *p = 21         // ポインタpを通してiへ値を代入する
  ```

- ポインタレシーバ
  - ひとつは、メソッドがレシーバが指す先の変数を変更するためです。
  - ふたつに、メソッドの呼び出し毎に変数のコピーを避けるためです。
  例えば、レシーバが大きな構造体である場合に効率的です。
  - メソッドがポインタレシーバである場合、呼び出し時に、変数、または、ポインタのいずれかのレシーバとして取ることができます:
  Goは利便性のため、 v.Scale(5) のステートメントを (&v).Scale(5) として解釈します。
  - メソッドが変数レシーバである場合、呼び出し時に、変数、または、ポインタのいずれかのレシーバとして取ることができます:
	この場合、 p.Abs() は (*p).Abs() として解釈されます。

## 論理演算子
- && 、||、!

## if文
- if condition {} else if {} else {}
  例.
  ```go
  x := 10
  if x > 10 {
      fmt.Println("x is greater than 10")
  } else if x == 10 {
      fmt.Println("x is exactly 10")
  } else {
      fmt.Println("x is less than 10")
  }
  ```
- ifの条件部分で変数定義、`if y:= xx; cond {}`
  例.
  ```go
  if y := 20; y > 10 {
    fmt.Println("y is greater than 10")
  }
  ```

## for文
- for文、`for i := 0; i < 10; i++ {}`

- collection要素をループ、`for index, item := range xxx`・`i,v := range xxx`
  例.
  ```go
  numbers := []int{10, 20, 30}
  for index, num := range numbers {
      fmt.Println(num)  // 10, 20, 30
  }
  ```
  例2.
  ```go
  person := map[string]int{"age": 30, "height": 170}
  for key, value := range person {
      fmt.Println(key, value)
  }
  ```
- break,continue
  ```go
  for i := 0; i < 5; i++ {
    if i == 3 {
        break
    }
    if i == 10 {
        continue
    }
    fmt.Println(i)  // 0, 1, 2
  }
  ```
## pythonでいうwhile文
- for condition {}
  例.
  ```go
  count := 0
  for count < 5 {
      fmt.Println(count)
      count++
  }
  ```

## 文字列
- 結合
  例.
  ```go
  result := s1 + ", " + s2
  ```
  例2.strings.Join(slice,"")
  ```go
  import (
    "fmt"
    "strings"
  )

  words := []string{"Hello", "World"}
  result := strings.Join(words, ", ") // Hello, World
  ```
- 文字探索、strings.Contains(s,"x")
- 文字列整形、fmt.Sprintf()
  例.
  ```go
  result := fmt.Sprintf("Name: %s, Age: %d", name, age) // Name: Alice, Age: 25
  ```
## 配列とslice
Go では 配列（array）とスライス（slice） の 2 種類があります。
- 配列、[num]型{}
Go の 配列は固定長
  例.
  ```go
  var arr [5]int = [5]int{1, 2, 3, 4, 5}  // 配列（固定長）
  ```
- slice、[]型{}
Go のスライスは 長さ（length）と容量（capacity） を持つ
- スライスは配列への参照のようなものです。
スライスはどんなデータも格納しておらず、単に元の配列の部分列を指し示しています。
スライスの要素を変更すると、その元となる配列の対応する要素が変更されます。

  - スライス作成、make([]type,要素,容量)
  例.
  ```go
  b := make([]int, 0, 5)
  ```
  例2.goだと最初に空のslice作ってから詰め込むイメージ
  ```go
  pic := make([][]uint8, dy)
  for y := range pic {
    pic[y] = make([]uint8, dx)
    for x := range pic[y] {
      pic[y][x] = uint8((x + y) / 2)
    }
  }
  ```
  例3.
  ```go
  var squares []int
  for x := 0; x < 10; x++ {
      squares = append(squares, x*x)  // [0 1 4 9 16 25 36 49 64 81]
  }
  ```

  - 要素追加、append(xxx,y)
  例.
  ```go
  slice := []int{1, 2, 3, 4, 5}  // スライス（可変長）
  slice = append(slice, 6)       // 追加
  ```
  例.配列の結合
  ・append() に ...（スプレッド演算子のようなもの）を付ける。
  ```go
  slice = append(slice, []int{4, 5}...)  // [1, 2, 3, 4, 5]
  ```
  - スライス、xxx[x:y]
  例.
  ```go
  slice := []int{10, 20, 30, 40, 50}
  subSlice := slice[1:4]
  ```
  - 長さ、len(xxx)
  スライスの長さは、それに含まれる要素の数です。
  スライスの容量は、スライスの最初の要素から数えて、元となる配列の要素数です。
  - index,valueの一覧取得、for index, value := range slice {}
  例.
  ```go
  for i, v := range slice {
      fmt.Println(i, v)
  }
  ```
  - 要素の検索、 Go には in や index() はなく、for を使って検索する。
  例.存在チェック
  ```go
  target := 20
  found := false
  for _, v := range slice {
      if v == target {
          found = true
          break
      }
  }
  ```
  例2.存在チェック
  ```go
  m := map[int]struct{}{}
  for _, s := range slice {
    m[s] = struct{}{}
  }
  _, ok := m[key]
  return ok
  ```
  例3.slicesパッケージを使う、slices.Contains(slice, key)
  ```go
  import (
    "golang.org/x/exp/slices"
  )
  slices.Contains(slice, key)
  ```

  例.インデックス検索
  ```go
  target = 30
  index := -1
  for i, v := range slice {
      if v == target {
          index = i
          break
      }
  }
  ```
  - map、filter
  for文で愚直にやる
    - map
    ```go
    slice := []int{1, 2, 3}
    for i := range slice {
      slice[i] *= 2
    }
    ```
    - filter
    ```go
    slice := []int{1, 2, 3, 4, 5}
    var filtered []int
    for _, v := range slice {
      if v%2 == 0 {
          filtered = append(filtered, v)
        }
    }
    ```

## map 型

- 変数定義: var m map[keyType]ValueType
  map[KeyType]ValueType と表されます。
  例.
  ```go
  var m map[string]int
  ```
  例2.xxx := map[KeyType]ValueType{}
  ```go
  person := map[string]int{
      "age": 30,
      "height": 170,
  }
  ```
  例3.mapに渡すトップレベルの型が単純な型名である場合は、リテラルの要素から推定できますので、その型名を省略可。
  ```go
  type Vertex struct {
  	Lat, Long float64
  }

  var m = map[string]Vertex{
    "Bell Labs": {40.68433, -74.39967},
    "Google":    {37.42202, -122.08408},
  }
  ```

- make(map[keyType]ValueType)、マップ作成
  m = make(map[string]int)

- key・value 設定
  m["key"] = value

- keyの存在確認、value, exists := xxx["key"]
  ```go
  // キーの存在確認
  if city, exists := person["city"]; exists {
      fmt.Println(city)
  } else {
      fmt.Println("Key not found") // Key not found
  }
  ```

- key,valueの一覧取得、for key, value := range map {}
  例.
  ```go
  for key, value := range person {
    fmt.Println(key, value)
  }
  ```

## 構造体(Struct)
- Go では struct を使って複数の異なる型を持つデータをまとめます。
struct (構造体)は、フィールド( field )の集まりです。
- structリテラルは、フィールドの値を列挙することで新しいstructの初期値の割り当てを示しています。
Name: 構文を使って、フィールドの一部だけを列挙することができます
```go
type Vertex struct {
	X, Y int
}

var (
	v1 = Vertex{1, 2}  // has type Vertex
	v2 = Vertex{X: 1}  // Y:0 is implicit
	v3 = Vertex{}      // X:0 and Y:0
	p  = &Vertex{1, 2} // has type *Vertex
)
```
- structのフィールドは、ドット( . )を用いてアクセスします。
例.
```go
type Person struct {
  Name string
  Age  int
}

p := Person{Name: "Alice", Age: 25}
```
→ Go の struct は Python のクラスのような役割を果たしますが、メソッドは明示的に定義する必要があります。

- Goには、クラス( class )のしくみはありませんが、型にメソッド( method )を定義できます。
メソッドは、レシーバー( receiver )を持ちます。
- ポインタレシーバ
```go
type Vertex struct {
	X, Y float64
}
// レシーバは、 func キーワードとメソッド名の間に自身の引数リストで表現します。
func (v Vertex) Abs() float64 {
	return math.Sqrt(v.X*v.X + v.Y*v.Y)
}

// ポインタレシーバでメソッドを宣言できます。
// これはレシーバの型が、ある型 T への構文 *T があることを意味します。 （なお、 T は *int のようなポインタ自身を取ることはできません）
// ポインタレシーバを持つメソッド(ここでは Scale )は、レシーバが指す変数を変更できます。
// レシーバ自身を更新することが多いため、変数レシーバよりもポインタレシーバの方が一般的です。
func (v *Vertex) Scale(f float64) {
	v.X = v.X * f
	v.Y = v.Y * f
}
```

## json
- JSON→構造体に変換（デコード / Unmarshal）、json.Unmarshal()
  例.
  ```go
  import (
    "encoding/json"
    "fmt"
  )

  type Person struct {
      Name string `json:"name"` // jsonのname→Nameにmapping
      Age  int    `json:"age"`
  }

  func main() {
      jsonStr := `{"name": "Alice", "age": 25}`
      var person Person

      err := json.Unmarshal([]byte(jsonStr), &person)
      if err != nil {
          fmt.Println("Error:", err)
          return
      }

      fmt.Println(person.Name) // Alice
      fmt.Println(person.Age)  // 25
  }
  ```
- 構造体→json、json.Marshal()
  例.
  ```go
  person := Person{Name: "Bob", Age: 30}

  jsonBytes, err := json.Marshal(person)
  if err != nil {
    fmt.Println("Error:", err)
    return
  }
  ```
## 関数

- func xxx(x 型) 型 {}
  例 1.
  ```go
  func add(x int, y int) int {return x + y}
  ```
- 複数の返り値、func xxx(x 型 1, y 型 2) (型 1,型 2) {}
  例 2.
  ```go
  func swap(x, y string) (string, string) {return y, x}
  a, b := swap("hello", "world")
  ```
- 戻り値の変数に名前をつける( named return value )
  例.
  ```go
  func split(sum int) (x, y int) {}
  ```
- 名前をつけた戻り値の変数を使うと、 return ステートメントに何も書かずに戻すことができます。
これを "naked" return と呼びます。
  ```go
  func split(sum int) (x, y int) {
    x = sum * 4 / 9
    y = sum - x
    return
  }
  ```
- 可変長引数は...で表現
  例.
  ```go
  func sumAll(nums ...int) int {
    sum := 0
    for _, num := range nums {
        sum += num
    }
    return sum
  }
  ```
- goではデフォルト引数がない
Go では デフォルト引数がないため、明示的に処理する。
  例.
  ```go
  func greet(name string) string {
    if name == "" {
        name = "Guest"
    }
    return "Hello, " + name
  }
  ```
- goではキーワード引数指定がない
代わりにGo では 構造体を引数として渡す ことで、キーワード引数のような記法が可能。
  例.
  ```go
  package main
  import "fmt"

  // 引数用の構造体
  type GreetOptions struct {
      Name string
      Age  int
  }

  // 構造体を引数に取る関数
  func greet(opts GreetOptions) {
      fmt.Printf("Hello, %s. You are %d years old.\n", opts.Name, opts.Age)
  }

  func main() {
      greet(GreetOptions{Name: "Alice", Age: 25})  // Hello, Alice. You are 25 years old.
      greet(GreetOptions{Age: 30, Name: "Bob"})    // Hello, Bob. You are 30 years old.
  }
  ```
- 無名関数 val := func () {}
  ```go
  add := func(a, b int) int {
      return a + b
  }
  fmt.Println(add(2, 3))  // 5
  ```

## エラー
- エラー処理、`result, err := xxx`
例. Go では try-except の代わりに、関数が error を返し、呼び出し側で if err != nil をチェックする。
  ```go
  func divide(a, b float64) (float64, error) {
    if b == 0 {
        return 0, errors.New("division by zero")
    }
    return a / b, nil
  }
  ```
- error 型は fmt.Stringer に似た組み込みのインタフェースです
  = Error() stringというメソッドを持てばerror型として扱える
  ```go
    type error interface {
      Error() string
    }
  ```
- エラー種別
Go では errors.Is() や errors.As() を使ってエラーの種類を判定する。
- errors.New("xx")でエラーオブジェクトを定義
  例.
  ```go
  import (
    "errors"
    "fmt"
  )

  var ErrInvalidInput = errors.New("invalid input")
  var ErrDivideByZero = errors.New("division by zero")

  func divide(a, b float64) (float64, error) {
      if b == 0 {
          return 0, ErrDivideByZero
      }
      return a / b, nil
  }

  func main() {
      _, err := divide(10, 0)
      if errors.Is(err, ErrDivideByZero) {
          fmt.Println("ZeroDivisionError:", err)
      } else if errors.Is(err, ErrInvalidInput) {
          fmt.Println("InvalidInputError:", err)
      } else if err != nil {
          fmt.Println("Other Error:", err)
      }
  }

  func main() {
      result, err := divide(10, 0)
      if err != nil {
          fmt.Println("Error:", err)
          return
      }
      fmt.Println("Result:", result)
  }
  ```

## 他

- pythonでいうfinally→defer
defer を使って 関数終了時に 実行
defer ステートメントは、 defer へ渡した関数の実行を、呼び出し元の関数の終わり(returnする)まで遅延させるものです。
defer へ渡した関数の引数は、すぐに評価されますが、その関数自体は呼び出し元の関数がreturnするまで実行されません。
例.
```go
func main() {
  fmt.Println("Processing...")
  defer fmt.Println("Cleanup done.")  // 関数の終了時に実行
  result := 10 / 2
  fmt.Println("Result:", result)
}
```

- print デバック
  ```go
  import "fmt"
  fmt.Println(add(42, 13))
  ```
