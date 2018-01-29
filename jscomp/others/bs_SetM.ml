
(* Copyright (C) 2017 Authors of BuckleScript
 * 
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 * 
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)


module N = Bs_internalAVLset
module A = Bs_Array
module Sort = Bs_SortArray


type ('k, 'id) dict = ('k, 'id) Bs_Cmp.t 
type ('key, 'id ) cmp = ('key, 'id) Bs_Cmp.cmp

module S = struct
  type ('elt,'id) t =
    {
      cmp: ('elt, 'id) cmp;
      mutable data: 'elt N.t
    } [@@bs.deriving abstract]
end

type ('k, 'id) t = ('k, 'id) S.t


let rec removeMutateAux nt x ~cmp = 
  let k = N.key nt in 
  let c = (Bs_Cmp.getCmpIntenral cmp) x k [@bs] in 
  if c = 0 then 
    let l,r = N.(left nt, right nt) in       
    match N.(toOpt l, toOpt r) with 
    | Some _,  Some nr ->  
      N.rightSet nt (N.removeMinAuxWithRootMutate nt nr);
      N.return (N.balMutate nt)
    | None, Some _ ->
      r  
    | (Some _ | None ), None ->  l 
  else 
    begin 
      if c < 0 then 
        match N.toOpt (N.left nt) with         
        | None -> N.return nt 
        | Some l ->
          N.leftSet nt (removeMutateAux ~cmp l x );
          N.return (N.balMutate nt)
      else 
        match N.toOpt (N.right nt) with 
        | None -> N.return nt 
        | Some r -> 
          N.rightSet nt (removeMutateAux ~cmp r x);
          N.return (N.balMutate nt)
    end

let remove  d  v =  
  let oldRoot = S.data d in 
  match N.toOpt oldRoot with 
  | None -> ()
  | Some oldRoot2 ->
    let newRoot = removeMutateAux ~cmp:(S.cmp d) oldRoot2 v in 
    if newRoot != oldRoot then 
      S.dataSet d newRoot    


let rec removeArrayMutateAux t xs i len ~cmp  =  
  if i < len then 
    let ele = A.getUnsafe xs i in 
    let u = removeMutateAux t ele ~cmp in 
    match N.toOpt u with 
    | None -> N.empty
    | Some t -> removeArrayMutateAux t xs (i+1) len ~cmp 
  else N.return t    

let removeMany d xs =  
  let oldRoot = S.data d in 
  match N.toOpt oldRoot with 
  | None -> ()
  | Some nt -> 
    let len = A.length xs in 
    let newRoot = removeArrayMutateAux nt xs 0 len ~cmp:(S.cmp d) in 
    if newRoot != oldRoot then 
      S.dataSet d newRoot


let rec removeMutateCheckAux  nt x removed ~cmp= 
  let k = N.key nt in 
  let c = (Bs_Cmp.getCmpIntenral cmp) x k [@bs] in 
  if c = 0 then 
    let () = removed := true in  
    let l,r = N.(left nt, right nt) in       
    match N.(toOpt l, toOpt r) with 
    | Some _,  Some nr ->  
      N.rightSet nt (N.removeMinAuxWithRootMutate nt nr);
      N.return (N.balMutate nt)
    | None, Some _ ->
      r  
    | (Some _ | None ), None ->  l 
  else 
    begin 
      if c < 0 then 
        match N.toOpt (N.left nt) with         
        | None -> N.return nt 
        | Some l ->
          N.leftSet nt (removeMutateCheckAux ~cmp l x removed);
          N.return (N.balMutate nt)
      else 
        match N.toOpt (N.right nt) with 
        | None -> N.return nt 
        | Some r -> 
          N.rightSet nt (removeMutateCheckAux ~cmp r x removed);
          N.return (N.balMutate nt)
    end



let removeCheck d v =  
  let oldRoot = S.data d in 
  match N.toOpt oldRoot with 
  | None -> false 
  | Some oldRoot2 ->
    let removed = ref false in 
    let newRoot = removeMutateCheckAux ~cmp:(S.cmp d) oldRoot2 v removed in 
    if newRoot != oldRoot then  
      S.dataSet d newRoot ;   
    !removed



let rec addMutateCheckAux  t x added ~cmp  =   
  match N.toOpt t with 
  | None -> 
    added := true;
    N.singleton x 
  | Some nt -> 
    let k = N.key nt in 
    let  c = (Bs_Cmp.getCmpIntenral cmp) x k [@bs] in  
    if c = 0 then t 
    else
      let l, r = N.(left nt, right nt) in 
      (if c < 0 then                   
         let ll = addMutateCheckAux ~cmp l x added in
         N.leftSet nt ll
       else   
         N.rightSet nt (addMutateCheckAux ~cmp r x added );
      );
      N.return (N.balMutate nt)

let addCheck m e = 
  let  oldRoot = S.data m in 
  let added = ref false in 
  let newRoot = addMutateCheckAux ~cmp:(S.cmp m) oldRoot e added in 
  if newRoot != oldRoot then 
    S.dataSet m newRoot;
  !added    


let split d  key  =     
  let arr = N.toArray (S.data d) in
  let cmp = S.cmp d in 
  let i = Sort.binarySearchBy arr key (Bs_Cmp.getCmpIntenral cmp)  in   
  let len = A.length arr in 
  if i < 0 then 
    let next = - i -1 in 
    (S.t 
       ~data:(N.ofSortedArrayAux arr 0 next)
       ~cmp
     , 
     S.t 
       ~data:(N.ofSortedArrayAux arr next (len - next))
       ~cmp
    ), false
  else 
    (S.t 
       ~data:(N.ofSortedArrayAux arr 0 i)
       ~cmp,
     S.t 
       ~data:(N.ofSortedArrayAux arr (i+1) (len - i - 1))
       ~cmp
    ), true       

let keepBy d p = 
  S.t ~data:(N.filterCopy (S.data d) p ) ~cmp:(S.cmp d)
    
let partition d p = 
  let cmp = S.cmp d in 
  let a, b = N.partitionCopy (S.data d) p in 
  S.t ~data:a ~cmp, S.t ~data:b ~cmp

let empty (type elt) (type id) ~(dict : (elt, id) dict) =
  let module M = (val dict) in 
  S.t ~cmp:M.cmp ~data:N.empty
    
let isEmpty d = 
  N.isEmpty (S.data d)
    
let minimum d = 
  N.minimum (S.data d)    
let minUndefined d =
  N.minUndefined (S.data d)
let maximum d = 
  N.maximum (S.data d)
let maxUndefined d =
  N.maxUndefined (S.data d)
let forEach d f =
  N.forEach (S.data d) f     
let reduce d acc cb = 
  N.reduce (S.data d) acc cb 
let every d p = 
  N.every (S.data d) p 
let some d  p = 
  N.some (S.data d) p   
let size d = 
  N.size (S.data d)
let toList d =
  N.toList (S.data d)
let toArray d = 
  N.toArray (S.data d)

let ofSortedArrayUnsafe (type elt) (type id) xs ~(dict : (elt,id) dict) : _ t =
  let module M = (val dict) in 
  S.t ~data:(N.ofSortedArrayUnsafe xs) ~cmp:M.cmp
    
let checkInvariantInternal d = 
  N.checkInvariantInternal (S.data d)
    
let cmp d0 d1 = 
  N.cmp ~cmp:(S.cmp d0) (S.data d0) (S.data d1)

let eq d0  d1 = 
  N.eq ~cmp:(S.cmp d0) (S.data d0) (S.data d1)
    
let get d x = 
  N.get ~cmp:(S.cmp d) (S.data d) x
    
let getUndefined  d x = 
  N.getUndefined ~cmp:(S.cmp d) (S.data d) x
    
let getExn d x = 
  N.getExn ~cmp:(S.cmp d) (S.data d) x
    
let has d x =
  N.has ~cmp:(S.cmp d) (S.data d) x
    
let ofArray (type elt) (type id)  data ~(dict : (elt,id) dict) =
  let module M = (val dict) in
  let cmp = M.cmp in 
  S.t ~cmp ~data:(N.ofArray ~cmp data)
    
let add m e = 
  let oldRoot = S.data m in 
  let newRoot = N.addMutate ~cmp:(S.cmp m) oldRoot e  in 
  if newRoot != oldRoot then 
    S.dataSet m newRoot

let addArrayMutate t xs ~cmp =     
  let v = ref t in 
  for i = 0 to A.length xs - 1 do 
    v := N.addMutate !v (A.getUnsafe xs i)  ~cmp
  done; 
  !v
    
let mergeMany d xs =   
  S.dataSet d (addArrayMutate (S.data d) xs ~cmp:(S.cmp d))


let subset a b = 
  N.subset  ~cmp:(S.cmp a) (S.data a) (S.data b)

let intersect a b  : _ t = 
  let cmp = S.cmp a  in 
  match N.toOpt (S.data a), N.toOpt (S.data b) with 
  | None, _ -> S.t ~cmp ~data:N.empty
  | _, None -> S.t ~cmp ~data:N.empty
  | Some dataa0, Some datab0 ->  
    let sizea, sizeb = 
      N.lengthNode dataa0, N.lengthNode datab0 in          
    let totalSize = sizea + sizeb in 
    let tmp = A.makeUninitializedUnsafe totalSize in 
    ignore @@ N.fillArray dataa0 0 tmp ; 
    ignore @@ N.fillArray datab0 sizea tmp;
    let p = Bs_Cmp.getCmpIntenral cmp in 
    if (p (A.getUnsafe tmp (sizea - 1))
          (A.getUnsafe tmp sizea) [@bs] < 0)
       || 
       (p 
          (A.getUnsafe tmp (totalSize - 1))
          (A.getUnsafe tmp 0) [@bs] < 0 
       )
    then S.t ~cmp ~data:N.empty
    else 
      let tmp2 = A.makeUninitializedUnsafe (min sizea sizeb) in 
      let k = Sort.intersect tmp 0 sizea tmp sizea sizeb tmp2 0 p in 
      S.t ~data:(N.ofSortedArrayAux tmp2 0 k)
        ~cmp
        
let diff a b : _ t = 
  let cmp = S.cmp a in 
  let dataa = S.data a in 
  match N.toOpt dataa, N.toOpt (S.data b) with 
  | None, _ -> S.t ~cmp ~data:N.empty
  | _, None -> 
    S.t ~data:(N.copy dataa) ~cmp
  | Some dataa0, Some datab0
    -> 
    let sizea, sizeb = N.lengthNode dataa0, N.lengthNode datab0 in  
    let totalSize = sizea + sizeb in 
    let tmp = A.makeUninitializedUnsafe totalSize in 
    ignore @@ N.fillArray dataa0 0 tmp ; 
    ignore @@ N.fillArray datab0 sizea tmp;
    let p = Bs_Cmp.getCmpIntenral cmp in 
    if (p (A.getUnsafe tmp (sizea - 1))
          (A.getUnsafe tmp sizea) [@bs] < 0)
       || 
       (p 
          (A.getUnsafe tmp (totalSize - 1))
          (A.getUnsafe tmp 0) [@bs] < 0 
       )
    then S.t ~data:(N.copy dataa) ~cmp
    else 
      let tmp2 = A.makeUninitializedUnsafe sizea in 
      let k = Sort.diff tmp 0 sizea tmp sizea sizeb tmp2 0 p in 
      S.t ~data:(N.ofSortedArrayAux tmp2 0 k) ~cmp

let union a b = 
  let cmp = S.cmp a in 
  let dataa, datab =  S.data a, S.data b  in 
  match N.toOpt dataa, N.toOpt datab with 
  | None, _ -> S.t ~data:(N.copy datab) ~cmp
  | _, None -> S.t ~data:(N.copy dataa) ~cmp
  | Some dataa0, Some datab0 
    -> 
    let sizea, sizeb = N.lengthNode dataa0, N.lengthNode datab0 in 
    let totalSize = sizea + sizeb in 
    let tmp = A.makeUninitializedUnsafe totalSize in 
    ignore @@ N.fillArray dataa0 0 tmp ;
    ignore @@ N.fillArray datab0 sizea tmp ;
    let p = (Bs_Cmp.getCmpIntenral cmp)  in 
    if p
        (A.getUnsafe tmp (sizea - 1))
        (A.getUnsafe tmp sizea) [@bs] < 0 then 
      S.t ~data:(N.ofSortedArrayAux tmp 0 totalSize) ~cmp
    else   
      let tmp2 = A.makeUninitializedUnsafe totalSize in 
      let k = Sort.union tmp 0 sizea tmp sizea sizeb tmp2 0 p in 
      S.t ~data:(N.ofSortedArrayAux tmp2 0 k) ~cmp

let copy d = S.t ~data:(N.copy (S.data d)) ~cmp:(S.cmp d)
