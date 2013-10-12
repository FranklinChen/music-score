{-# LANGUAGE     
    DeriveFunctor,
    DeriveFoldable,
    DeriveTraversable,
    NoMonomorphismRestriction,
    GeneralizedNewtypeDeriving,
    StandaloneDeriving,
    TypeFamilies,
    ViewPatterns,

    MultiParamTypeClasses,
    -- TypeSynonymInstances,
    -- FlexibleInstances,
    
    OverloadedStrings,
    TypeOperators
    #-}

import Data.Monoid.Action
import Data.Monoid.MList -- misplaced Action () instance

import Data.Default
import Data.AffineSpace
import Data.AffineSpace.Point
import Data.AdditiveGroup hiding (Sum, getSum)
import Data.VectorSpace hiding (Sum, getSum)
import Data.LinearMap

import Control.Monad
import Control.Arrow
import Control.Applicative
import Control.Monad.Writer hiding ((<>))
import Data.String
import Data.Semigroup
import Data.Foldable (Foldable)
import Data.Traversable (Traversable)
import qualified Data.Traversable as T
import qualified Diagrams.Core.Transform as D

{-
    Compare
        - Update Monads: Cointerpreting directed containers
-}

newtype Foo m a = Foo (Writer m a)
    deriving (Monad, MonadWriter m, Functor, Foldable, Traversable)

newtype Writer2 m a = Writer2 (a, m)
    deriving (Show, Functor, Foldable, Traversable)
instance Monoid m => Monad (Writer2 m) where
    return x = Writer2 (x, mempty)
    Writer2 (x1,m1) >>= f = let
        Writer2 (x2,m2) = f x1
        in Writer2 (x2,m1 `mappend` m2)

-- instance Functor ((,) a)
deriving instance Monoid m => Foldable ((,) m)
deriving instance Monoid m => Traversable ((,) m)
instance Monoid m => Monad ((,) m) where
    return x =  (mempty, x)
    (m1,x1) >>= f = let
        (m2,x2) = f x1
        in (m1 `mappend` m2,x2)


newtype RawBar m a = RawBar { getRawBar :: [(m,a)] }
    deriving (Show, Semigroup, Monoid, Functor, Foldable, Traversable)
instance Monoid m => Monad (RawBar m) where
    return = RawBar . return . return
    RawBar xs >>= f = RawBar $ xs >>= joinTrav (getRawBar . f)



newtype Bar m a = Bar { getBar :: [Foo m a] }
    deriving (Semigroup, Monoid, Functor, Foldable, Traversable)
instance Monoid m => Applicative (Bar m) where
    pure = return
    (<*>) = ap
instance Monoid m => Monad (Bar m) where
    return = Bar . return . return
    Bar xs >>= f = Bar $ xs >>= joinTrav (getBar . f)

joinTrav :: (Monad t, Traversable t, Applicative f) => (a -> f (t b)) -> t a -> f (t b)
joinTrav f = fmap join . T.traverse f

{-
join' :: Monad t => t (t b) -> t b
join' = join

joinedSeq :: (Monad t, Traversable t, Applicative f) => t (f (t a)) -> f (t a)
joinedSeq = fmap join . T.sequenceA


bindSeq :: (Monad f, Applicative f, Traversable t) => f (t (f a)) -> f (t a)
bindSeq = bind T.sequenceA 

travBind :: (Monad f, Applicative f, Traversable t) => (a -> f b) -> t (f a) -> f (t b)
travBind f = T.traverse (bind f)
-}

{-
    Free theorem of sequence/dist    
        sequence . fmap (fmap k)  =  fmap (fmap k) . sequence

    Corollaries
        traverse (f . g)  =  traverse f . fmap g
        traverse (fmap k . f)  =  fmap (fmap k)  =   traverse f

-}

runFoo :: Foo w a -> (a, w)
runFoo (Foo x) = runWriter x

runBar :: Bar w a -> [(a, w)]
runBar (Bar xs) = fmap runFoo xs

tells :: Monoid m => m -> Bar m a -> Bar m a
tells a (Bar xs) = Bar $ fmap (tell a >>) xs




----------------------------------------------------------------------

type Annotated a = Bar [String] a
runAnnotated :: Annotated a -> [(a, [String])]
runAnnotated = runBar

-- annotate all elements in bar
annotate :: String -> Annotated a -> Annotated a
annotate x = tells [x]

-- a bar with no annotations
x :: Annotated Int
x = return 0

-- annotations compose with >>=
y :: Annotated Int
y = x <> annotate "a" x >>= (annotate "b" . return)

-- and with join
z :: Annotated Int
z = join $ annotate "d" $ return (annotate "c" (return 0) <> return 1)

-- runBar y ==> [(0,"b"),(0,"ab")]
-- runBar z ==> [(0,"dc"),(1,"d")]


----------------------------------------------------------------------

type Time = Double
type Dur = Double

newtype Span = Span (Time,Dur)
    -- deriving (Semigroup,Monoid)

-- type TT = [String]
-- 
-- applyTT :: TT -> (Time, Dur) -> (Time, Dur)
-- applyTT m x = (m,x)
-- 
-- delaying :: Time -> TT
-- delaying x = return $ "delay " ++ show x
-- 
-- stretching :: Dur -> TT
-- stretching x = return $ "stretch " ++ show x

newtype TT = TT (D.Transformation (Time,Dur))
    deriving (Monoid, Semigroup)

applyTT :: TT -> (Time, Dur) -> (Time, Dur)
applyTT t = unPoint . D.papply t . P
    
delaying :: Time -> TT
delaying x = D.translation (x,0)

stretching :: Dur -> TT
stretching = D.scaling

-- addTT :: TT -> Bar TT a -> Bar TT a
-- addTT = tells

----------------------------------------------------------------------

-- Compose time transformations with another Monoid
-- Generalize this pattern?

-- Monoid and Semigroup instances compose by default
-- 'tells' works with all Monoids
-- Need a way to generalize constructors and apply

type TT2 = ([String],TT)
-- Monoid, Semigroup

liftTT2 :: TT -> TT2
liftTT2 = monR

monL :: Monoid b => a -> (a, b)
monL = swap . return

-- This is the Writer monad again
monR :: Monoid b => a -> (b, a)
monR = return

type PT = () -- Semigroup, Monoid
type DT = () -- Semigroup, Monoid
type AT = () -- Semigroup, Monoid
type RT = () -- Semigroup, Monoid

-- Nice pattern here!
type T = ((((((),AT),RT),DT),PT),TT)
 -- Semigroup, Monoid
idT = (mempty::T)

newtype Tx = Tx T
    deriving (Monoid, Semigroup)

-- TODO How to generalize applyTT2 (?)
-- All apply functions convert the monoidal transformation to
-- an endofunction (a -> a)

-- applyTT :: TT -> (Time, Dur) -> (Time, Dur)
-- applyPT :: PT -> Pitch     -> Pitch
-- applyDT :: PT -> Amplitude -> Amplitude
-- applyRT :: RT -> Part      -> Part
-- applyAT :: AT -> (Pitch, Amplitude) -> (Pitch, Amplitude)
-- applyST :: AT -> Point R3 -> Point R3
-- applyUnit :: () -> a -> a

-- This is Monoidal actions!

instance Action TT Span where
    act = applyTT
instance (Action t a, Action u b) => Action (t, u) (a, b) where
    act (t, u) (a, b) = (act t a, act u b)



applyTT2 :: TT2 -> (Time, Dur) -> ((Time, Dur), [String])
applyTT2 (as,t) x = (applyTT t x, as)
    
delaying2 :: Time -> TT2
delaying2 x = liftTT2 $ delaying x

stretching2 :: Dur -> TT2
stretching2 x = liftTT2 $ stretching x

-- addTT2 :: TT2 -> Bar TT2 a -> Bar TT2 a
-- addTT2 = tells

----------------------------------------------------------------------
delay :: Time -> Bar TT a -> Bar TT a
delay x = tells (delaying x)

stretch :: Dur -> Bar TT a -> Bar TT a
stretch x = tells (stretching x)

----------------------------------------------------------------------


type Score = Bar TT
-- Monoid, Functor, Applicative, Monad, Foldable, Traversable
instance (IsString a, Monoid m) => IsString (Bar m a) where
    fromString = return . fromString

-- runScore :: Score a -> [((Time, Time), a)]
-- runScore = fmap (swap . fmap (flip applyTT (0,1))) . runBar

runScore :: Action m b => b -> Bar m a -> [(b, a)]
runScore x = fmap (swap . fmap ((flip act) x)) . runBar

foo :: Score String
foo = stretch 2 $
    "c" <> (delay 1 ("d" <> stretch 0.1 "e"))



-- ((0.0,2.0),"c")
-- ((2.0,2.0),"d")
-- ((2.0,0.2),"e")
-- ((["stretch 2.0"],(0,1)),"c")
-- ((["stretch 2.0","delay 1.0"],(0,1)),"d")
-- ((["stretch 2.0","delay 1.0","stretch 0.1"],(0,1)),"e")

-- (0,1)
-- (0,0.5)
-- (1,0.5)
-- (2,1)



swap (x,y) = (y,x)