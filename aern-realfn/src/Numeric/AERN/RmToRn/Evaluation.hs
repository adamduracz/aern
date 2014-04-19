{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-|
    Module      :  Numeric.AERN.RmToRn.Evaluate
    Description :  operations focusing on function evaluation  
    Copyright   :  (c) Michal Konecny
    License     :  BSD3

    Maintainer  :  mikkonecny@gmail.com
    Stability   :  experimental
    Portability :  portable
    
    Operations focusing on function evaluation.
-}

module Numeric.AERN.RmToRn.Evaluation where

import Numeric.AERN.RmToRn.Domain
import Numeric.AERN.RmToRn.New

import qualified Numeric.AERN.RealArithmetic.RefinementOrderRounding as ArithInOut
import Numeric.AERN.RealArithmetic.RefinementOrderRounding ((<+>), (<*>|), (</>|))

import qualified Numeric.AERN.RefinementOrder as RefOrd
import qualified Numeric.AERN.NumericOrder as NumOrd

import Numeric.AERN.Basics.Effort
import Numeric.AERN.Basics.Consistency

--import Numeric.AERN.Misc.Debug

class (HasDomainBox f) => CanEvaluateOtherType f
    where
    type EvalOps f :: * -> *
    evalOtherType :: 
        (Show t, RefOrd.IntervalLike t) 
        => 
        (EvalOps f t) -> (VarBox f t) -> f -> t

class (CanEvaluateOtherType f) => CanEvaluateOtherTypeInner f
    where
    evalOtherTypeInner :: 
        (Show t, RefOrd.IntervalLike t, HasAntiConsistency t) 
        => 
        (EvalOps f t) -> (VarBox f t) -> f -> t

class 
    (CanEvaluateOtherType f,
     EffortIndicator (EvalOpsEffortIndicator f t)) 
    => 
    HasEvalOps f t
    where
    type EvalOpsEffortIndicator f t
    evalOpsDefaultEffort :: f -> t -> EvalOpsEffortIndicator f t
    evalOpsEff :: EvalOpsEffortIndicator f t -> f -> t -> EvalOps f t 

{-
    The following are special cases of the above, which
    can sometimes be implemented more efficiently.
-}

class 
    (HasDomainBox f,
     EffortIndicator (EvaluationEffortIndicator f)) 
    => 
    CanEvaluate f
    where
    type EvaluationEffortIndicator f
    evaluationDefaultEffort :: f -> EvaluationEffortIndicator f
    evalAtPointOutEff :: 
        EvaluationEffortIndicator f -> 
        (DomainBox f) {-^ a sub-domain @A@ where to evaluate -} -> 
        f {-^ function @f@ -} -> 
        (Domain f) {-^ approximated range of @f@ over @A@ -}
    evalAtPointInEff ::
        EvaluationEffortIndicator f -> 
        (DomainBox f) {-^ a sub-domain @A@ where to evaluate -} -> 
        f {-^ function @f@ -} -> 
        (Domain f) {-^ approximated range of @f@ over @A@ -}
    
evalAtPointOut ::
        CanEvaluate f => 
        (DomainBox f) {-^ a sub-domain @A@ where to evaluate -} -> 
        f {-^ function @f@ -} -> 
        (Domain f) {-^ approximated range of @f@ over @A@ -}
evalAtPointOut dombox f =
    evalAtPointOutEff (evaluationDefaultEffort f) dombox f
    
evalAtPointIn ::
        CanEvaluate f => 
        (DomainBox f) {-^ a sub-domain @A@ where to evaluate -} -> 
        f {-^ function @f@ -} -> 
        (Domain f) {-^ approximated range of @f@ over @A@ -}
evalAtPointIn dombox f =
    evalAtPointInEff (evaluationDefaultEffort f) dombox f
    
evalSamplesEff :: 
    (ArithInOut.RoundedReal (Domain f), 
     RefOrd.IntervalLike (Domain f), 
     CanEvaluate f) 
    =>
    EvaluationEffortIndicator f -> 
    Int {-^ @n@ - Take (n+1) samples in each dimension. -} -> 
    DomainBox f {-^ @area@ - Area to evaluate the functions over -} -> 
    [f] {-^ @[f1, f2, ...]@ - Functions to evaluate -} -> 
    [[Domain f]] -- ^ @[[f1(sample1), f2(sample1), ...], [f1(sample2), f2(sample2), ...], ]@ 
evalSamplesEff effEval n area (fns :: [f]) =
    map evalPt points
    where
    evalPt pt =
        map (evalAtPointOutEff effEval pt) fns
    points =
        map fromAscList $ allCombinations $ map addChoices areaCoords
        where
        addChoices (var, a) 
            | aIsExact = [(var, a)]
            | otherwise = [(var, aPicked) | aPicked <- choices]
            where
            aIsExact = (aL NumOrd.==? aR) == Just True
            choices = 
                [aL, aR] ++ [midPoint i  | i <- [1..(n-1)]]
                where
                midPoint i = ((aL <*>| i) <+> (aR <*>| (n - i))) </>| n
            (aL, aR) = RefOrd.getEndpointsOut a
        
    areaCoords :: [(Var f, Domain f)]
    areaCoords = toAscList area
        
allCombinations :: [[a]] -> [[a]]
allCombinations [] = [[]]
allCombinations (options : rest) =
    [option : restCombination | 
        option <- options, 
        restCombination <- allCombinations rest] 

    
    
class 
    (HasDomainBox f,
     EffortIndicator (PartialEvaluationEffortIndicator f)) 
    => 
    CanPartiallyEvaluate f
    where
    type PartialEvaluationEffortIndicator f
    partialEvaluationDefaultEffort :: f -> PartialEvaluationEffortIndicator f
    pEvalAtPointOutEff :: 
        PartialEvaluationEffortIndicator f -> 
        (DomainBox f) {-^ values for some of the variables in @f@ -} -> 
        f {-^ function @f@ -} -> 
        f {-^ approximation of the specialised function in the remaning, unevaluated, variables -}
    pEvalAtPointInEff ::
        PartialEvaluationEffortIndicator f -> 
        (DomainBox f) {-^ values for some of the variables in @f@ -} -> 
        f {-^ function @f@ -} -> 
        f {-^ approximation of the specialised function in the remaning, unevaluated, variables -}
    
pEvalAtPointOut ::
        CanPartiallyEvaluate f => 
        (DomainBox f) {-^ a sub-domain @A@ where to evaluate -} -> 
        f {-^ function @f@ -} -> 
        f {-^ approximation of the specialised function in the remaning, unevaluated, variables -}
pEvalAtPointOut dombox f =
    pEvalAtPointOutEff (partialEvaluationDefaultEffort f) dombox f
    
pEvalAtPointIn ::
        CanPartiallyEvaluate f => 
        (DomainBox f) {-^ a sub-domain @A@ where to evaluate -} -> 
        f {-^ function @f@ -} -> 
        f {-^ approximation of the specialised function in the remaning, unevaluated, variables -}
pEvalAtPointIn dombox f =
    pEvalAtPointInEff (partialEvaluationDefaultEffort f) dombox f
    
{-
    Properties and tests of CanEvaluate are in the Laws module
    to avoid a circular dependency on that module.
    Laws requires Evaluation and the property requires
    a function defined in Laws.
-}
    
class
    (HasDomainBox f, HasProjections f, HasVarValue (VarBox f f) (Var f) f) 
    => 
    CanCompose f
    where
    type CompositionEffortIndicator f
    compositionDefaultEffort :: f -> CompositionEffortIndicator f
    composeVarsOutEff ::
        CompositionEffortIndicator f -> 
        (VarBox f f) 
            {-^ 
                For some variables, a function with domain @D'@.
                The domain @D'@ must include the dimensions of @D@ that
                are not to be substituted by another value according to this box.  
            -} 
        -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
    composeVarsInEff ::
        CompositionEffortIndicator f -> 
        (VarBox f f) 
            {-^ 
                For some variables, a function with domain @D'@.
                The domain @D'@ must include the dimensions of @D@ that
                are not to be substituted by another value according to this box.  
            -} 
        -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
    composeVarOutEff ::
        CompositionEffortIndicator f ->
        (Var f) {-^ variable @v@ -} -> 
        f {-^ a function with domain @D'@ to substitute for variable @v@  -} -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
    composeVarOutEff eff var value fn =  -- default
        composeVarsOutEff eff valueBox fn
        where
        valueBox = insertVar var value var2selfBox
        var2selfBox = fromAscList $ zip vars projections
        (vars, _) = unzip $ toAscList $ getDomainBox fn
        projections = map (newProjectionFromSample value) vars 
    composeVarInEff ::
        CompositionEffortIndicator f -> 
        (Var f) {-^ variable @v@ -} -> 
        f {-^ a function with domain @D'@ to substitute for variable @v@  -} -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
    composeVarInEff eff var value fn =  -- default
        composeVarsInEff eff valueBox fn
        where
        valueBox = insertVar var value var2selfBox
        var2selfBox = fromAscList $ zip vars projections
        (vars, _) = unzip $ toAscList $ getDomainBox fn
        projections = map (newProjectionFromSample value) vars 
        
composeVarsOut ::
        CanCompose f => 
        (VarBox f f) 
            {-^ 
                For some variables, a function with domain @D'@.
                The domain @D'@ must include the dimensions of @D@ that
                are not to be substituted by another value according to this box.  
            -} 
        -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
composeVarsOut valueBox fn =
    composeVarsOutEff (compositionDefaultEffort fn) valueBox fn
        
composeVarsIn ::
        CanCompose f => 
        (VarBox f f) 
            {-^ 
                For some variables, a function with domain @D'@.
                The domain @D'@ must include the dimensions of @D@ that
                are not to be substituted by another value according to this box.  
            -} 
        -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
composeVarsIn valueBox fn =
    composeVarsInEff (compositionDefaultEffort fn) valueBox fn

composeVarOut ::
        CanCompose f => 
        (Var f) {-^ variable @v@ -} -> 
        f {-^ a function with domain @D'@ to substitute for variable @v@  -} -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
composeVarOut var value fn =
    composeVarOutEff (compositionDefaultEffort fn) var value fn

composeVarIn ::
        CanCompose f => 
        (Var f) {-^ variable @v@ -} -> 
        f {-^ a function with domain @D'@ to substitute for variable @v@  -} -> 
        f {-^ a function @f@ with domain @D@ -} -> 
        f {-^ an approximation of the composition of function @f@ with the given functions -}
composeVarIn var value fn =
    composeVarInEff (compositionDefaultEffort fn) var value fn
        
        