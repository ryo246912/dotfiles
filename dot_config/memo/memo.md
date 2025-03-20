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
