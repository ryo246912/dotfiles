# 1. Go

## 1.1. 備忘録
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
