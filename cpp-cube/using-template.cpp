

template<typename C, typename A>
using True = C;

template<typename C, typename A>
using False = A;

template<typename Z, typename S>
using Zero = Z;

template<typename x, typename Z, typename S>
using Suc = S<x<Z, S> >;

template<typename Z, typename S>
using One = S<Z>;

template<typename Z, typename S>
using Two = S<One<Z, S> >;

template<typename a, template<typename Z_, template<typename x_> typename S_> typename b, typename Z, typename S>
using Plus = a<b<Z, S>, S>;

template<typename Z, typename S>
using TpT = Plus<Two, Two, Z, S>;


template<typename x>
using LessThan_KF = False;

template<typename x>
using LessThan_KT = True;

/*
template<typename a, typename b>
using LessThan = a<b<False, LessThan_KT>, 
*/

template< template<typename Z, typename S> typename x>
using IsNonZero = x<False, LessThan_KT>;

template<typename C, typename A>
using TpTIsNonZero = IsNonZero<TpT><C, A>;

TpTIsNonZero<int, char*> res = "foo";