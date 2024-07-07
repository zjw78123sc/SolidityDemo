// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
//First App
//First Application

//Here is a simple contract that you can get, increment and decrement the count store in this contract.
contract Counter{
    uint256 public  count;
    // Function to get the current count
    function get() public  view returns  (uint256){
        return  count;
    }

    //Funtion to increment count by 1
    function inc() public {
        count += 1;
    }

    //Funtions to decrease count by 1
    function dec() public {
        // This vill fail if count = 0
        count -= 1;
    }


}