{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImplicitParams #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-|
    Module      :  Numeric.AERN.IVP.Specification.Hybrid
    Description :  specification of hybrid system IVP with uncertainty
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Specification of hybrid system IVP with uncertainty.
-}

module Numeric.AERN.IVP.Specification.Hybrid
--(
--)
where

import Numeric.AERN.RmToRn.Domain
--import Numeric.AERN.RmToRn.New

import qualified Data.Set as Set
import qualified Data.Map as Map

--import Numeric.AERN.RmToRn.Evaluation
--import Numeric.AERN.RmToRn.Integration
--
--import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
--import Numeric.AERN.RealArithmetic.RefinementOrderRounding.OpsImplicitEffort
--import Numeric.AERN.RealArithmetic.ExactOps
--
--import qualified Numeric.AERN.NumericOrder as NumOrd
--import Numeric.AERN.NumericOrder.OpsDefaultEffort
--
--import qualified Numeric.AERN.RefinementOrder as RefOrd
--import Numeric.AERN.RefinementOrder.OpsImplicitEffort

--import Numeric.AERN.Misc.Debug



data HybridIVP f =
    HybridIVP
    {
        hybivp_system :: HybridSystem f
    , 
        hybivp_tVar :: Var f -- ^ @tVar@
    ,
        hybivp_tStart :: Domain f -- ^ @tStart@
    ,
        hybivp_tEnd :: Domain f -- ^ @tEnd@
    ,
        hybivp_makeInitialValueFnVec :: HybridSystemUncertainState f 
        {-^ 
        -} 
    }

data HybridSystem f =
    HybridSystem
    {
        hybsys_componentNames :: [Var f]
    ,
        hybsys_modeFields :: Map.Map HybSysMode ([f] -> [f])
    ,
        hybsys_eventModeSwitchesAndResetFunctions :: Map.Map HybSysEventKind (HybSysMode, [f] -> [f])
    ,
        hybsys_eventDetector :: HybSysMode -> [f] -> Set.Set HybSysEventKind 
    }
    
newtype HybSysMode = HybSysMode String deriving (Eq, Ord, Show)
newtype HybSysEventKind = HybSysEventKind String deriving (Eq, Ord, Show)
    
data HybridSystemUncertainState f =
    HybridSystemUncertainState
    {
        hybstate_mode :: Set.Set HybSysMode
    ,
        hybstate_values :: [f]
    }