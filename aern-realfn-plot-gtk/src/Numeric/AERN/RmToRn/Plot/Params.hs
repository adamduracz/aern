{-# LANGUAGE DeriveDataTypeable   #-}
{-|
    Module      :  Numeric.AERN.RmToRn.Plot.Params
    Description :  parameters for function plotting
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Data defining in detail how to plot a function and
    low-level methods related to plotting.
-}
module Numeric.AERN.RmToRn.Plot.Params 
(
    FnPlotStyle(..),
    defaultFnPlotStyle,
    black,
    red,
    green,
    blue,
    ColourRGBA,
    CanvasParams(..),
    defaultCanvasParams,
    CoordSystem(..),
    Rectangle(..),
    translateToCoordSystem,
    getVisibleDomExtents
)
where

import Numeric.AERN.RealArithmetic.ExactOps

import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut

--import qualified Numeric.AERN.NumericOrder as NumOrd

import qualified Numeric.AERN.RefinementOrder as RefOrd

--import Data.Typeable
--import Data.Generics.Basics

--import Data.Binary

data FnPlotStyle =
    FnPlotStyle
    {
        styleOutlineColour :: Maybe ColourRGBA,
        styleFillColour :: Maybe ColourRGBA,
        styleOutlineThickness :: Double
    }
    deriving (Eq, Show)

type ColourRGBA = (Double, Double, Double, Double)

defaultFnPlotStyle :: FnPlotStyle
defaultFnPlotStyle =
    FnPlotStyle
    {
        styleOutlineColour = Just (0,0,0,1), -- black
        styleFillColour = Just (0,0,0,0.1), -- transparent black
        styleOutlineThickness = 0.5
    }

black :: FnPlotStyle
black = defaultFnPlotStyle
red :: FnPlotStyle
red = defaultFnPlotStyle 
    { 
        styleOutlineColour = Just (0.8,0.2,0.2,1), 
        styleFillColour = Just (0.8,0.2,0.2,0.1) 
    } 
green :: FnPlotStyle
green = defaultFnPlotStyle 
    { 
        styleOutlineColour = Just (0.2,0.8,0.2,1), 
        styleFillColour = Just (0.2,0.8,0.2,0.1) 
    } 
blue :: FnPlotStyle
blue = defaultFnPlotStyle 
    { 
        styleOutlineColour = Just (0.1,0.1,0.8,1), 
        styleFillColour = Just (0.1,0.1,0.8,0.1) 
    } 


data CanvasParams t =
    CanvasParams
    {
        cnvprmCoordSystem :: CoordSystem t, 
        cnvprmShowAxes :: Bool,
        cnvprmShowSampleValuesFontSize :: Maybe Double, 
        cnvprmBackgroundColour :: Maybe ColourRGBA,
        cnvprmSamplesPerUnit :: Int
    }
    deriving (Eq, Show) --, Typeable, Data)
  

  
--{- the following has been generated by BinaryDerive -}     
--instance Binary CanvasParams where
--  put (CanvasParams a b c) = put a >> put b >> put c
--  get = get >>= \a -> get >>= \b -> get >>= \c -> return (CanvasParams a b c)
--{- the above has been generated by BinaryDerive -}
  
data CoordSystem t
    = CoordSystemLinear (Rectangle t)
--    | CoordSystemLog (Rectangle t)
--    | CoordSystemSqueeze t
    | CoordSystemLogSqueeze t
    deriving (Ord, Show) --, Typeable, Data)
    
instance (RefOrd.PartialComparison t) => Eq (CoordSystem t)
    where
    (CoordSystemLogSqueeze _) == (CoordSystemLogSqueeze _) = True
    (CoordSystemLinear rect1) == (CoordSystemLinear rect2) = rect1 == rect2
    _ == _ = False

data Rectangle t =
    Rectangle 
    {
        rectTop :: t,
        rectBottom :: t,
        rectLeft :: t,
        rectRight :: t
    }
    deriving (Ord, Show) --, Typeable, Data)
    
instance (Functor Rectangle)
    where
    fmap f (Rectangle a b c d) = Rectangle (f a) (f b) (f c) (f d)
    
instance (RefOrd.PartialComparison t) => Eq (Rectangle t)
    where
    (Rectangle t1 b1 l1 r1) == (Rectangle t2 b2 l2 r2) =
        (t1 `eq` t2) && 
        (b1 `eq` b2) && 
        (l1 `eq` l2) && 
        (r1 `eq` r2)
        where
        a `eq` b = Just True == RefOrd.pEqualEff (RefOrd.pCompareDefaultEffort a) a b  

--{- the following has been generated by BinaryDerive -}
--instance Binary CoordSystem where
--  put (CoordSystemLinear a) = putWord8 0 >> put a
--  put (CoordSystemLog a) = putWord8 1 >> put a
--  put CoordSystemSqueeze = putWord8 2
--  put CoordSystemLogSqueeze = putWord8 3
--  get = do
--    tag_ <- getWord8
--    case tag_ of
--      0 -> get >>= \a -> return (CoordSystemLinear a)
--      1 -> get >>= \a -> return (CoordSystemLog a)
--      2 -> return CoordSystemSqueeze
--      3 -> return CoordSystemLogSqueeze
--      _ -> fail "no parse"
--instance Binary Rectangle where
--  put (Rectangle a b c d) = put a >> put b >> put c >> put d
--  get = get >>= \a -> get >>= \b -> get >>= \c -> get >>= \d -> return (Rectangle a b c d)
--{- the above has been generated by BinaryDerive -}

    
defaultCanvasParams ::
    (HasZero t, HasOne t)
    =>
    t -> CanvasParams t
defaultCanvasParams sample =
    CanvasParams
    {
        cnvprmCoordSystem = CoordSystemLinear (Rectangle c1 c0 c0 c1),
        cnvprmShowAxes = True,
        cnvprmShowSampleValuesFontSize = Just 12,
        cnvprmBackgroundColour = 
            Just (0.8,0.85,0.9,1), -- light blue
        cnvprmSamplesPerUnit = 200
    }
    where
    c0 = zero sample
    c1 = one sample
    
{-|
    Translate a point given by two coordinates to
    a 2D point assuming that only result points in the rectangle
    (0,0) --- (1,1) are visible, the origin being at the bottom left.
-}
translateToCoordSystem ::
    (ArithInOut.RoundedReal t) 
    =>
    (ArithInOut.RoundedRealEffortIndicator t) ->
    CoordSystem t ->
    (t, t) ->
    (t, t)
translateToCoordSystem eff csys _pt@(x,y) =
    case csys of
        CoordSystemLogSqueeze _scale ->
            error "CoordSystemLogSqueeze current not supported."
--            ((logSqueeze 0.5 x) * scale, (logSqueeze 0.5 y) * scale)
        CoordSystemLinear (Rectangle t b l r) ->
            ((linTransform l r x), 
             (linTransform b t y))
    where
    linTransform x0 x1 x2 =
        (x2 <-> x0) </> (x1 <-> x0)

    (<->) = ArithInOut.subtrOutEff effAdd
    (</>) = ArithInOut.divOutEff effDiv

    effAdd =
        ArithInOut.fldEffortAdd sample $ ArithInOut.rrEffortField sample eff
    effDiv =
        ArithInOut.fldEffortDiv sample $ ArithInOut.rrEffortField sample eff
    sample = x
    
    
    
--    logSqueeze v1 =
--        (\x -> (x + 1) /2) . (normalise v1) . logScale
    
getVisibleDomExtents ::
    (HasInfinities t)
    => 
    CoordSystem t -> 
    (t,t,t,t)
getVisibleDomExtents csys =
    case csys of
        CoordSystemLogSqueeze sample -> 
            (plusInfinity sample, 
             minusInfinity sample, 
             minusInfinity sample, 
             plusInfinity sample)
        CoordSystemLinear (Rectangle t b l r) ->
            (t, b, l, r)
    
--{-|
--    Convert a number from range [-oo,+oo] to
--    range (-1,1), mapping 1 to v1.
---}
--normalise :: 
--    (ArithInOut.RoundedReal t) 
--    =>
--    (ArithInOut.RoundedRealEffortIndicator t) -> 
--    t {-^ v1 -} -> 
--    t {-^ x -} -> 
--    t
--normalise eff v1 x
--    | v1ok && x < c0 = 
--        (a</>(a <-> x)) <-> c1
--    | v1ok = 
--        c1 <-> (a</>(a <+> x))
--    where
--    v1ok = 
--        c0 < v1 && v1 < c1
--    a = 
--        (c1 <-> v1) </> v1
--    c0 = zero sample
--    c1 = one sample
--
--    a < b = 
--        (NumOrd.pLessEff effComp a b) == Just True
--    (<+>) = ArithInOut.addOutEff effAdd
--    (<->) = ArithInOut.subtrOutEff effAdd
--    (</>) = ArithInOut.divOutEff effDiv
--
--    sample = x
--    effComp =
--        ArithInOut.rrEffortNumComp sample eff
--    effAdd =
--        ArithInOut.fldEffortAdd sample $ ArithInOut.rrEffortField sample eff
--    effDiv =
--        ArithInOut.fldEffortDiv sample $ ArithInOut.rrEffortField sample eff
    
--{-|
--    Map the range [-oo,oo] to itself with a logarithmic scale.
---}
--logScale :: 
--    (ArithInOut.RoundedReal t) 
--    => 
--    (ArithInOut.RoundedRealEffortIndicator t) ->
--    t -> t
--logScale eff x
--    | (x <? 0) == Just True = - (logScale (neg x))
--    | otherwise = ArithInOut.logOutEff effLog (x <+> 1)
--    where
--    (<?) = NumOrd.pLessEff effComp

    