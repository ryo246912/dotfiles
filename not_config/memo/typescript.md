# 1. TypeScript

## 1.1. テンプレートリテラル型 `${T}`

- 文字列型の一種、${}の中に式ではなく型が入る`Hello ${string}`
  例.

```ts
fuction makeKey <T extends string >(userName : T) {
  return `user:${userName}` as const
}
```

## 1.2. ユニオン型

- A | B extends Y ? S : T → (A extends Y ? Sa : Ta) | (B extends Y ? Sb : Tb)、ユニオン分配 (union distribution)
  例.

```ts
type IsString<T> = T extends string ? true : false;
type C = IsString<string | number>; //boolean
```

## 1.3. オブジェクト型

### 1.3.1. {[key:string] : T}、インデックス型: key を指定しない

```ts
type T = { [key: string]: string | number };
```

### 1.3.2. typeof 値 :値から型を抽出できる、オブジェクトからは対応した型を抽出できる

例.

```ts
const point = { x: 135, y: 35 };
type Point = typeof point; //{x: number;y: number;}
```

### 1.3.3. keyof T : (obj → key(union))オブジェクト型からプロパティ名の型を取得(だいたいリテラル型のユニオンになる)

- 例 1
  ```ts
  type Human = { name: string; age: number };
  type HumanKeys = keyof Human; // "name" | "age"型
  ```
- 例 2、keyof typeof オブジェクト(オブジェクトから一気に key のユニオンが取れる)
  ```ts
  const mmConversionTable = { mm: 1, m: 1e3, km: 1e6 };
  type x = keyof typeof mmConversionTable; // "mm" | "m" | "km"型
  ```
- 例 3. K extends keyof T : オブジェクト型の key のユニオン型を指定
  ```ts
  function get<T, K extends keyof T>(obj: T, key: K): T[K] {
    return obj[key];
  }
  ```

## 1.4. インデックスアクセス型:オブジェクト型["プロパティ名"]・配列型[number];

### 1.4.1. 基本

- T["key1" | "key2"]・T[1 | 2]、アクセスには Union 型も使え、返り値はユニオンそれぞれを満たすユニオン型が返ってくる
  例.

  ```ts
  type Person = { name: string; age: number };
  type T = Person["name" | "age"]; // string | number
  ```

  例 2.T["length"] : 配列の、T['length'] はその 長さの型 を取り出せる

  ```ts
  type First<T extends any[]> = T["length"] extends 0 ? never : T[0];
  ```

- T[keyof T] : (obj → value(union))keyof 型演算子と組み合わせると、オブジェクトの全プロパティの型がユニオン型で得られる
  型オブジェクト T に対して、keyof T でそれぞれ取り出すイメージ
- key を得たい keyof T
- value を得たい T[keyof T]

```ts
type Foo = { a: number; b: string; c: boolean };
type T = Foo[keyof Foo]; // string | number | boolean
```

### 1.4.2. T[number] : (arr → value) 配列型から要素の型を取り出す

```ts
const array = [null, "a", "b"];
type T = (typeof array)[number]; // string | null
```

### 1.4.3. T[K] : (obj → value)型の value の値を取得(lookup 型、オブジェクトの value アクセスの型版)

```ts
type Human = { type: "human"; name: string; age: number };
Human["age"]; //number 型
```

### 1.4.4. { [P in K ] : T} : 新たな obj 型を作成、主に文字列リテラル型のユニオン型から新しいオブジェクトの型を作成する

例 1.

```ts
type Fruit = "apple" | "orange" | "strawberry";
type FruitNumbers = { [P in Fruit]: number }; // {apple : number ; orange : number ; strawberry : number }
```

例 2.

```ts
type MyReadonly<T> = { readonly [K in keyof T]: T[K] };
```

### 1.4.5. X extends Y ? S : T、条件型

extends で型の true/false を表現するイメージ
例.

```ts
type First<T extends any[]> = T extends [] ? never : T[0];
```

### 1.4.6. T extends infer S ? X : Y、条件(T extends S の S のとこ)に infer S と書くと、S に補足された型を X の部分で再利用可能になります。

例.※`<S extends string>`は markdown の関係で``で囲っている

```ts
type ExtractHelloedPart`<S extends string>`= S extends`Hello, ${infer P}!` ? P : unknown;
```

## 1.5. ユーティリティ型

### 1.5.1. Required<T>:オブジェクトのプロパティを必須にする

```ts
type Person = { surname: string; middleName?: string; givenName: string };
type RequiredPerson = Required<Person>; // {surname: string; middleName: string; givenName: string;}
```

### 1.5.2. Partial<T> : オブジェクトの型 T のすべてのプロパティをオプションプロパティにする

```ts
type Person = { surname: string; middleName?: string; givenName: string };
type PartialPerson = Partial<Person>; // {surname?: string | undefined; middleName?: string | undefined; givenName?: string | undefined; };
```

### 1.5.3. Pick<T,K>型 : オブジェクト T 型の一部を取り出す, K にはプロパティキーを指定する

```ts
type T = Pick<{ name: string; age: number }, "age">; //{age : number}
```

### 1.5.4. NonNullable<T> : null と undefined の型を除く、Exclude<T , null | undefined>と同様

```ts
type String1 = NonNullable<string>; //string
type String2 = NonNullable<string | null>; // string
type String3 = NonNullable<string | undefined>; // string
type String4 = NonNullable<string | null | undefined>; //string
```

### 1.5.5. Record<Keys, Type> : key,value の型を指定したオブジェクトの型を作る(特に keys を特定の key 名に限定するときとかに使う)

例 1.キーが string で値が number のインデックス型を定義する。

```ts
type StringNumber = Record<string, number>;
const value: StringNumber = { a: 1, b: 2, c: 3 };
```

例 2.キーが firstName、middleName、familyName で、値が文字列になるオブジェクトの型を定義する。

```ts
type Person = Record<"firstName" | "middleName" | "lastName", string>;
const person: Person = {
  firstName: "Robert",
  middleName: "Cecil",
  lastName: "Martin",
};
```

### 1.5.6. ReturnType<T> : 関数の戻り値の型を取得する

例 1.

```ts
type ReturnType1 = ReturnType<() => string>; //string
type ReturnType2 = ReturnType<(arg: string) => string | number>; // string | number
type ReturnType3 = ReturnType<() => never>; // never
```

例 2. ReturnType<typeof func> : typeof func で関数の型を取得して、一気に返り値の型まで取得する
