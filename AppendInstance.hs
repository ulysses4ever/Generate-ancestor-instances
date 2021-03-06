module AppendInstance where

import DynFlags
import FastString
import HsSyn
import Lexer
import Outputable
import qualified Parser
import RdrName
import SrcLoc
import StaticFlags
import StringBuffer
import qualified GHC
import Bag
import Name

import Data.List

import HsDecls
import HsTypes
import HsBinds

import System.Environment

takeFirstArg :: HsType RdrName -> HsType RdrName
takeFirstArg (HsAppTy a b) = unLoc a

takeSecondArg :: HsType RdrName -> HsType RdrName
takeSecondArg (HsAppTy a b) = unLoc b

putOutInnerHsType :: HsType RdrName -> HsType RdrName
putOutInnerHsType (HsForAllTy a b c d e) = unLoc e

hsTypeToString :: HsType RdrName -> String
hsTypeToString = showSDocUnsafe . ppr

mkRdrName :: String -> RdrName
mkRdrName = mkVarUnqual . fsLit

mkFunId :: String -> Located RdrName
mkFunId = noLoc . mkRdrName

applicative :: HsType RdrName
applicative = HsTyVar (mkRdrName "Applicative")

functor :: HsType RdrName
functor = HsTyVar (mkRdrName "Functor")

deflHsTyVarBndrs :: LHsTyVarBndrs RdrName
deflHsTyVarBndrs = HsQTvs { hsq_kvs = []
                          , hsq_tvs = [] }

mkInstHead :: (HsType RdrName) -> (LHsType RdrName)
mkInstHead mydata = noLoc (HsForAllTy Explicit Nothing 
                    deflHsTyVarBndrs (noLoc [])
                    (noLoc (HsAppTy (noLoc applicative) 
                    (noLoc mydata))))

instanceApplicative :: LHsType RdrName -> LHsBinds RdrName
                                            -> ClsInstDecl RdrName
instanceApplicative insthead funs = ClsInstDecl { 
                                        cid_poly_ty       = insthead
                                      , cid_binds         = funs
                                      , cid_sigs          = []
                                      , cid_tyfam_insts   = []
                                      , cid_datafam_insts = []
                                      , cid_overlap_mode  = Nothing
                                            }

-- "Pulls out" the declarations from the module 
-- (that are inside of Located)
getHsModDecls :: IO (Maybe (HsModule RdrName)) 
                                    -> IO (Maybe [LHsDecl RdrName])
getHsModDecls md = do
    mp <- md
    case mp of
        Nothing  -> return Nothing
        Just mdl -> return $ Just (hsmodDecls mdl)

-- "Pulls out" the declarations from Located
getHsDecls :: IO (Maybe [LHsDecl RdrName]) 
                            -> IO (Maybe [HsDecl RdrName])
getHsDecls md = do
    mp <- md
    case mp of
        Nothing  -> return Nothing
        Just mdl -> return $ Just (map unLoc mdl)

-- This is necessary for the next fuction (getInstDecls)
isInstDecl :: HsDecl RdrName -> Bool
isInstDecl (InstD _) = True
isInstDecl _         = False

getOneInstDecl :: HsDecl RdrName -> InstDecl RdrName
getOneInstDecl (InstD (a)) = a

-- "Pulls out" the Instance declarations
getInstDecls :: IO (Maybe [HsDecl RdrName]) 
                                    -> IO (Maybe [InstDecl RdrName])
getInstDecls md = do
    mp <- md
    case mp of 
        Nothing  -> return Nothing
        Just mdl -> return $ Just (map getOneInstDecl
                                            $ filter isInstDecl mdl)

-- "Pulls out" the class instance declarations
getClsInstDecl :: IO (Maybe [InstDecl RdrName]) 
                                    -> IO (Maybe [ClsInstDecl RdrName])
getClsInstDecl md = do
    mp <- md
    case mp of
        Nothing  -> return Nothing
        Just mdl -> return $ Just (map cid_inst 
                                            $ filter isClsInstDecl mdl)

-- Checks if it is a class instance declaration
isClsInstDecl :: InstDecl RdrName -> Bool
isClsInstDecl (ClsInstD _ ) = True
isClsInstDecl _             = False

whatClassIsInstance :: ClsInstDecl RdrName -> HsType RdrName
whatClassIsInstance = takeFirstArg . putOutInnerHsType 
                        . unLoc . cid_poly_ty

takeUserData :: ClsInstDecl RdrName -> HsType RdrName
takeUserData = takeSecondArg . putOutInnerHsType 
                        . unLoc . cid_poly_ty

isInstanceMonad :: ClsInstDecl RdrName -> Bool
isInstanceMonad instD = 
    ((hsTypeToString . whatClassIsInstance) instD) == "Monad"

isInstanceApplicative :: ClsInstDecl RdrName -> Bool
isInstanceApplicative instD = 
   ((hsTypeToString . whatClassIsInstance) instD) == "Applicative"

isInstanceFunctor :: ClsInstDecl RdrName -> Bool
isInstanceFunctor instD = 
    ((hsTypeToString . whatClassIsInstance) instD) == "Functor"

-- "Pulls out" HsType (is contained in ClsInstDecl)
getHsType :: IO (Maybe [ClsInstDecl RdrName])
                                        -> IO (Maybe [HsType RdrName])
getHsType md = do
    mp <- md
    case mp of
        Nothing  -> return Nothing
        Just mdl -> return $ Just (map (unLoc . cid_poly_ty) mdl)

{-isHsDocTy :: HsType RdrName -> Bool
isHsDocTy (HsDocTy _ _) = True
isHsDocTy _             = False

showHsDocTy :: IO (Maybe [ClsInstDecl RdrName])
                                        -> IO (Maybe [String])
showHsDocTy = do
    mp <- md
    case mp of
        Nothing  -> return Nothing
        Just mdl -> return $ Just (map (showSDocUnsafe . pprParendHsType
                            . isHsDocTy
                            . unLoc . cid_poly_ty) mdl)-}

-- HsType is shown up inside of the brackets; 
-- it is necessary to delete them
deleteBrackets :: String -> String
deleteBrackets = init . tail

-- "Pulls" the HsBinds out of ClsInstDecl
getHsBinds :: IO (Maybe [ClsInstDecl RdrName])
                           -> IO (Maybe [[HsBindLR RdrName RdrName]])
getHsBinds md = do
    mp <- md
    case mp of
        Nothing  -> return Nothing
        Just mdl -> return $ Just (map ((map unLoc) . bagToList 
                                                . cid_binds) mdl)
