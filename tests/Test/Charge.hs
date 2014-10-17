{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}
module Test.Charge where

import           Control.Monad
import           Control.Monad.IO.Class (liftIO)
import           Data.Either
import           Data.Text              (Text)
import           Test.Config            (getConfig)
import           Test.Hspec
import           Web.Stripe
import           Web.Stripe.Charge
import           Web.Stripe.Customer

chargeTests :: Spec
chargeTests =
  describe "Charge tests" $ do
    chargeCustomerTest
    retrieveChargeTest
    updateChargeTest
    retrieveExpandedChargeTest
    retrieveAllChargesTest
    captureChargeTest
  where
    cn  = CardNumber "4242424242424242"
    em  = ExpMonth 12
    ey  = ExpYear 2015
    cvc = CVC "123"
    chargeCustomerTest = 
      it "Charges a customer succesfully" $ do
        config <- getConfig
        result <- stripe config $ do
          Customer { customerId = cid } <- createCustomerByCard cn em ey cvc
          charge <- chargeCustomer cid (Currency "usd") 100 Nothing
          void $ deleteCustomer cid
          return charge
        result `shouldSatisfy` isRight

    retrieveChargeTest = 
      it "Retrieves a charge succesfully" $ do
        config <- getConfig
        result <- stripe config $ do
          Customer { customerId = cid } <- createCustomerByCard cn em ey cvc
          Charge { chargeId = chid } <- chargeCustomer cid (Currency "usd") 100 Nothing
          result <- getCharge chid
          void $ deleteCustomer cid
          return result
        result `shouldSatisfy` isRight

    updateChargeTest =
      it "Updates a charge succesfully" $ do
        config <- getConfig
        result <- stripe config $ do
          Customer { customerId = cid } <- createCustomerByCard cn em ey cvc
          Charge { chargeId = chid } <- chargeCustomer cid (Currency "usd") 100 Nothing
          _ <- updateCharge chid "Cool" [("hi", "there")]
          result <- getCharge chid
          void $ deleteCustomer cid
          return result
        result `shouldSatisfy` isRight
        let Right Charge { chargeMetaData = cmd, chargeDescription = desc } = result
        cmd `shouldSatisfy` (\x -> ("hi", "there") `elem` x)
        desc `shouldSatisfy` (==(Just "Cool" :: Maybe Text))

    retrieveExpandedChargeTest =
      it "Retrieves an expanded charge succesfully" $ do
        config <- getConfig
        result <- stripe config $ do
          Customer { customerId = cid } <- createCustomerByCard cn em ey cvc
          Charge { chargeId = chid } <- chargeCustomer cid (Currency "usd") 100 Nothing
          result <- getChargeExpandable chid ["balance_transaction", "customer", "invoice"]
          void $ deleteCustomer cid
          return result
        result `shouldSatisfy` isRight
    
    retrieveAllChargesTest =
      it "Retrieves all charges" $ do
        config <- getConfig
        result <- stripe config $ getCharges Nothing Nothing Nothing
        result `shouldSatisfy` isRight

    captureChargeTest = 
      it "Captures a charge" $ do
        config <- getConfig
        result <- stripe config $ do
          Customer { customerId = cid } <- createCustomerByCard cn em ey cvc
          Charge { chargeId = chid } <- chargeBase 100 (Currency "usd") Nothing (Just cid)
                                        Nothing Nothing Nothing False 
                                        Nothing Nothing Nothing Nothing []
          result <- captureCharge chid Nothing Nothing
          void $ deleteCustomer cid
          return result
        result `shouldSatisfy` isRight
        let Right (Charge { chargeCaptured = captured }) = result
        captured `shouldSatisfy` (==True)