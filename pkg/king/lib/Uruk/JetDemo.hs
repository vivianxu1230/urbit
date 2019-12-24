{-
    This is an extremely simple (and very, very slow) Uruk evaluator.

    It evaluates Uruk by applying reduction rules until we reach a normal
    form, and printing the expression after every reduction.

    This is an extremely dumb evaluation strategy, but it's dead simple
    and closely matches the spec. It's also a useful debugging tool,
    since it shows each reduction step.
-}

module Uruk.JetDemo
    ( Ur(..)
    , normalize
    , reduce
    , jam
    , church
    , unChurch
    , dash
    , j1, j2, j3, j4
    , j_nat
    , j_zer, l_zer, zer
    , j_inc, l_inc, inc
    , j_one, l_one, one
    , j_fol, l_fol, fol
    , j_dec, l_dec, dec
    , j_mul, l_mul, mul
    , j_sub, l_sub, sub
    , j_add, l_add, add
    , j_uni, l_uni, uni
    , j_lef, l_lef, lef
    , j_rit, l_rit, rit
    , j_cas, l_cas, cas
    , j_con, l_con, con
    , j_car, l_car, car
    , j_cdr, l_cdr, cdr
    , Match(..)
    , urVal, valUr
    , jetExp
    , pattern I
    ) where

import ClassyPrelude

-- ort Control.Arrow ((>>>))
import Data.Bits
import Data.Function    ((&))
import GHC.Natural      (Natural)


-- Types -----------------------------------------------------------------------

infixl 5 :@;

data Ur
    = S
    | K
    | D
    | J Natural
    | Nat Natural
    | Fol
    | Add
    | Inc
    | Dec
    | Mul
    | Sub
    | Uni
    | Lef
    | Rit
    | Cas
    | Con
    | Car
    | Cdr
    | Ur :@ Ur
    | Jc Natural Ur Ur [Ur]
  deriving (Eq, Ord)

jetExpand ∷ Natural → Ur
jetExpand = go
  where go = \case { 0 → no; 1 → J 1; n → go (pred n) :@ J 1 }
        no = error "impossible J value"

jetUnclosure ∷ Natural → Ur → Ur → [Ur] → Ur
jetUnclosure n tag bod = go (J n :@ tag :@ bod) . reverse
  where go acc = \case { [] → acc; x:xs → go (acc :@ x) xs }

instance Show Ur where
    show = \case
        x :@ y      → "[" <> intercalate " " (show <$> flatten x [y]) <> "]"
        J n         → replicate (fromIntegral n) '0'
        K           → "1"
        S           → "2"
        D           → "3"
        Jc n t b xs → close n t b xs

        Nat n       → "#" <> show n

        Fol         → "fol"
        Add         → "add"
        Inc         → "inc"
        Dec         → "dec"
        Mul         → "mul"
        Sub         → "sub"

        Lef         → "lef"
        Rit         → "rit"
        Cas         → "cas"

        Con         → "con"
        Car         → "car"
        Cdr         → "cdr"
        Uni         → "uni"

      where
        flatten (x :@ y) acc = flatten x (y : acc)
        flatten x        acc = (x : acc)

        close n t b = \case
            [] → mconcat [ "{", show (J n), " ", show t, " ", show b, "}" ]
            xs → mconcat [ "<"
                         , close n t b []
                         , " "
                         , intercalate " " (show <$> reverse xs)
                         , ">"
                         ]


-- Normalized Values -----------------------------------------------------------

newtype Val = MkVal { valUr ∷ Ur }
  deriving newtype (Eq, Ord, Show)

urVal ∷ Ur → Val
urVal ur =
    reduce ur & \case
        Nothing → MkVal ur
        Just ru → urVal ru


-- Named Functions -------------------------------------------------------------

data Named a = Named { _nName ∷ String, unNamed ∷ a }

instance Show (Named a) where
  show (Named s _) = s



--------------------------------------------------------------------------------

data Match = MkMatch
    { mFast ∷ Val
    , mArgs ∷ Word
    , mName ∷ Val
    , mBody ∷ Val
    }
  deriving (Show)

match ∷ Ur → Natural → Ur → Ur → Match
match j n t b = MkMatch (urVal j) (fromIntegral n) (urVal t) (urVal b)

data Check = MkCheck
    { cArgs ∷ Word
    , cName ∷ Val
    , cPred ∷ Named (Val → Maybe Val)
    }
  deriving (Show)

check ∷ String → Natural → Ur → (Val → Maybe Ur) → Check
check nm n t p = MkCheck (fromIntegral n) (urVal t)
               $ Named nm (fmap urVal <$> p)

type DashEntry = ((Word, Val), Named (Val → Maybe Val))
type DashBoard = Map (Word, Val) [Named (Val → Maybe Val)]

simpleEnt ∷ Match → DashEntry
simpleEnt MkMatch{..} =
    (,) (mArgs, mName)
        (Named (show mBody) (\b → guard (b==mBody) $> mFast))

predikEnt ∷ Check → DashEntry
predikEnt MkCheck{..} = ((cArgs, cName), cPred)

mkDash ∷ [DashEntry] → DashBoard
mkDash = foldl' go mempty
  where
    go ∷ DashBoard → DashEntry → DashBoard
    go acc (k,v) = lookup k acc & \case
                       Nothing → insertMap k [v] acc
                       Just vs → insertMap k (v:vs) acc

dashLookup ∷ Natural → Ur → Ur → Maybe Ur
dashLookup n t b = lookup (fromIntegral n, MkVal t) dash & \case
    Nothing → Nothing
    Just xs → valUr <$> asum (($ b') . unNamed <$> xs)
  where
    b' = urVal b


-- Jet Dashboard ---------------------------------------------------------------

unChurch ∷ Ur → Maybe Natural
unChurch = \case
    S :@ K                   -> Just 0
    S :@ (S:@(K:@S):@K) :@ n -> succ <$> unChurch n
    _                        -> Nothing

emp ∷ Ur
emp = K

pattern I = S :@ K :@ K

j1 = J 1 :@ K
j2 = J 2 :@ K
j3 = J 3 :@ K
j4 = J 4 :@ K

{-
    TODO:

    Jet registration becomes an infinite loop because jet bodies are
    normalized, but jet matching in the bodies depends on the jet
    dashboard, which depends on the normalized jet body.

    Giving each jet a unique name would solve this, but maybe it's still
    posible to run into this problem by accident? Whatever.

    For now, I'm hacking around this by using a unjetted version of
    `fol` in jet bodies.
-}

ch_succ = S :@ (S :@ (K :@ S) :@ K)
ch_zero = S :@ K

--  zer = \i z -> z
--  suc = \n -> \i z -> i (n i z)
--  one = inc zer
--  fol = \n -> n inc zer
--  inc = \n -> j2 (\i z -> i (fol n i z))
--  add = \x y -> j2 (fol (\i z -> (fol x) i (fol y)))
--  uni = K
--  dec = \n -> C (n (\x -> C x (\y -> R zer) (\y -> R (inc y))) (L uni))
--                (\g -> L uni)
--                (\g -> R (j2 (fol g)))
--  mul =
--  sub = \x y -> y (\z -> CAS z LEF DEC) (RIT x)
--  lef = \x l r -> l x
--  rit = \x l r -> r x
--  cas = \b l r -> b l r
--  con = \x y f -> f x y
--  car = \p -> p (\x y -> x)
--  cdr = \p -> b (\x y -> y)
l_zer = S :@ K
l_one = S :@ (S:@(K:@S):@K) :@ (S:@K)
l_fol = S :@ (S:@I:@(K:@(S:@(S:@(K:@S):@K)))) :@ (K:@(S:@K))
l_inc = S :@ (K:@j2) :@ (S:@(K:@(S:@(S:@(K:@S):@K))) :@ l_fol)
l_dec = S:@(S:@(S:@(K:@cas):@(S:@(S:@I:@(K:@(S:@(S:@cas:@(K:@(K:@(rit:@ch_zero)))):@(K:@(S:@(K:@rit):@ch_succ))))):@(K:@(lef:@uni)))):@(K:@(K:@(lef :@ uni)))):@(K:@(S:@(K:@rit):@(S:@(K:@j2):@fol)))
l_mul = D :@ D :@ D -- TODO
l_sub = S:@(K:@(S:@(S:@I:@(K:@(S:@(S:@cas:@(K:@lef)):@(K:@l_dec)))))):@(S:@(K:@K):@rit)
l_add = S :@ (K:@(S:@(K:@j2))) :@ (S:@(K:@(S:@(K:@l_fol))):@(S:@(K:@(S:@(K:@(S:@(K:@K))))):@(S:@(S:@(K:@(S:@(K:@(S:@(K:@S):@K)):@S)):@l_fol):@(K:@(S:@(K:@K):@l_fol)))))
l_uni = K
l_lef = S :@ (K:@(S:@(K:@(S:@(K:@K))):@(S:@I))) :@ K
l_rit = S :@ (K:@(S:@(K:@K):@(S:@I))) :@ K
l_cas = I
l_con = S:@(K:@(S:@(K:@(S:@(K:@(S:@(K:@(S:@S:@(K:@K))):@K)):@S)):@(S:@I))):@K
l_car = S:@I:@(K:@K)
l_cdr = S:@I:@(K:@(S:@K))









zer = jetExp j_zer
one = jetExp j_one
fol = jetExp j_fol
inc = jetExp j_inc
add = jetExp j_add
dec = jetExp j_dec
mul = jetExp j_mul
sub = jetExp j_sub
uni = jetExp j_uni
lef = jetExp j_lef
rit = jetExp j_rit
cas = jetExp j_cas
con = jetExp j_con
car = jetExp j_car
cdr = jetExp j_cdr

j_zer = match (Nat 0) 2 emp l_zer
j_one = match (Nat 1) 2 emp l_one
j_nat = check "nat" 2 K (fmap Nat <$> unChurch . valUr)

j_fol = match Fol 1 emp l_fol
j_inc = match Inc 1 emp l_inc
j_dec = match Dec 1 emp l_dec
j_mul = match Mul 2 emp l_mul
j_sub = match Sub 2 emp l_sub
j_add = match Add 2 emp l_add
j_uni = match Uni 1 emp l_uni
j_lef = match Lef 3 emp l_lef
j_rit = match Rit 3 emp l_rit
j_cas = match Cas 3 emp l_cas
j_con = match Con 3 emp l_con
j_car = match Car 1 emp l_car
j_cdr = match Cdr 1 emp l_cdr

dash ∷ DashBoard
dash = mkDash -- $ const [] $
    [ simpleEnt j_zer
    , simpleEnt j_one
    , simpleEnt j_fol
    , simpleEnt j_inc
    , simpleEnt j_add
--  , simpleEnt j_dec
    , simpleEnt j_sub
    , simpleEnt j_uni
    , simpleEnt j_lef
    , simpleEnt j_rit
    , simpleEnt j_con
    , simpleEnt j_car
    , simpleEnt j_cdr
    , predikEnt j_nat
    ]


-- Evaluation ------------------------------------------------------------------

--
--  Repeatedly perform reductions until the input is fully normalized.
--
normalize ∷ Ur → IO Ur
normalize ur = do
    putStrLn (">>  " <> tshow ur)
    reduce ur & \case
        Nothing -> pure ur
        Just ru -> normalize ru

--
--  Perform one reduction step. Return Nothing if the input is fully
--  normalized.
--
reduce ∷ Ur → Maybe Ur
reduce = \case
    (reduce → Just xv) :@ y → Just (xv :@ y)
    x :@ (reduce → Just yv) → Just (x  :@ yv)

    -- Uruk
    K :@ x :@ y      → Just x
    S :@ x :@ y :@ z → Just (x:@z:@(y:@z))
    D :@ x           → Just (jam x)
    J n :@ J 1       → Just (J (succ n))
    J n :@ t :@ b    → dashLookup n t b <|> pure (Jc n t b [])

    Jc n t b xs | n==len xs → Just (apply b xs)
    Jc n t b xs :@ x        → Just (Jc n t b (x:xs))

    --  Fire jet
    Nat n :@ x :@ y → Just (church n :@ x :@ y)

    Fol :@ x → x & \case
        Nat x → Just (church x)
        x     → Just (l_fol :@ x)

    Inc :@ x → Just $ case x of
        Nat n → Nat (succ n)
        x     → l_inc :@ x

    Dec :@ x → Just $ case x of
        Nat 0 → Lef :@ Uni
        Nat n → Rit :@ Nat (pred n)
        x     → l_rit :@ x

    Add :@ x :@ y → Just $ case (x, y) of
        (Nat x, Nat y) → Nat (x+y)
        (x,     y    ) → l_add :@ x :@ y

    Sub :@ x :@ y → Just $ case (x, y) of
        (Nat x, Nat y) → if y > x then Lef :@ Uni else Rit :@ Nat (x-y)
        (_,     _    ) → l_sub :@ x :@ y

    Cas :@ (Lef :@ x) :@ l :@ r → Just (l :@ x)
    Cas :@ (Rit :@ x) :@ l :@ r → Just (r :@ x)
    Cas :@ x          :@ l :@ r → Just (l_cas :@ l :@ r)

    Con :@ x :@ y :@ z → Just (z :@ x :@ y)

    Car :@ (Con :@ x :@ _) → Just x
    Car :@ p               → Just (l_car :@ p)

    Cdr :@ (Con :@ _ :@ y) → Just y
    Cdr :@ p               → Just (l_cdr :@ p)

    Rit :@ x :@ _ :@ r → Just (r :@ x)
    Lef :@ x :@ l :@ _ → Just (l :@ x)

    --  Doesn't reduce
    _ → Nothing
  where
    len = fromIntegral . length

    apply ∷ Ur → [Ur] → Ur
    apply f = go f . reverse
      where go acc = \case { [] → acc; x:xs → go (acc :@ x) xs }

jetBod ∷ Match → Ur
jetBod = valUr . mBody

jetExp ∷ Match → Ur
jetExp (MkMatch _ n t b) = J (fromIntegral n) :@ valUr t :@ valUr b

--
--  Produces a jetted, church-encoded natural number.
--
church ∷ Natural → Ur
church 0 = S :@ K
church n = S :@ (S:@(K:@S):@K) :@ church (pred n)

churchJet ∷ Natural → Ur
churchJet n = J 2 :@ K :@ church n

--
--  Serialize and Uruk expression and church-encode it.
--
jam ∷ Ur → Ur
jam = churchJet . snd . go
  where
    go ∷ Ur → (Int, Natural)
    go Inc           = go (jetExp j_inc)
    go Fol           = go (jetExp j_fol)
    go Dec           = go (jetExp j_dec)
    go Mul           = go (jetExp j_mul)
    go Sub           = go (jetExp j_sub)
    go Add           = go (jetExp j_add)
    go Uni           = go (jetExp j_uni)
    go Lef           = go (jetExp j_lef)
    go Rit           = go (jetExp j_rit)
    go Cas           = go (jetExp j_cas)
    go Con           = go (jetExp j_con)
    go Car           = go (jetExp j_car)
    go Cdr           = go (jetExp j_cdr)
    go (Nat n)       = go (churchJet n)
    go S             = (3, 0)
    go K             = (3, 2)
    go D             = (3, 4)
    go (J 1)         = (3, 6)
    go (J n)         = go (jetExpand n)
    go (Jc n t b xs) = go (jetUnclosure n t b xs)
    go (x:@y)  = (rBits, rNum)
        where (xBits, xNum) = go x
              (yBits, yNum) = go y
              rBits = 1 + xBits + yBits
              rNum  = 1 .|. shiftL xNum 1
                        .|. shiftL yNum (1+xBits)
