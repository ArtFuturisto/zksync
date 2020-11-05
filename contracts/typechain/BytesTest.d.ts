/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */

import {
  ethers,
  EventFilter,
  Signer,
  BigNumber,
  BigNumberish,
  PopulatedTransaction,
} from "ethers";
import {
  Contract,
  ContractTransaction,
  CallOverrides,
} from "@ethersproject/contracts";
import { BytesLike } from "@ethersproject/bytes";
import { Listener, Provider } from "@ethersproject/providers";
import { FunctionFragment, EventFragment, Result } from "@ethersproject/abi";

interface BytesTestInterface extends ethers.utils.Interface {
  functions: {
    "bytesToHexConvert(bytes)": FunctionFragment;
    "read(bytes,uint256,uint256)": FunctionFragment;
    "testUInt24(uint24)": FunctionFragment;
  };

  encodeFunctionData(
    functionFragment: "bytesToHexConvert",
    values: [BytesLike]
  ): string;
  encodeFunctionData(
    functionFragment: "read",
    values: [BytesLike, BigNumberish, BigNumberish]
  ): string;
  encodeFunctionData(
    functionFragment: "testUInt24",
    values: [BigNumberish]
  ): string;

  decodeFunctionResult(
    functionFragment: "bytesToHexConvert",
    data: BytesLike
  ): Result;
  decodeFunctionResult(functionFragment: "read", data: BytesLike): Result;
  decodeFunctionResult(functionFragment: "testUInt24", data: BytesLike): Result;

  events: {};
}

export class BytesTest extends Contract {
  connect(signerOrProvider: Signer | Provider | string): this;
  attach(addressOrName: string): this;
  deployed(): Promise<this>;

  on(event: EventFilter | string, listener: Listener): this;
  once(event: EventFilter | string, listener: Listener): this;
  addListener(eventName: EventFilter | string, listener: Listener): this;
  removeAllListeners(eventName: EventFilter | string): this;
  removeListener(eventName: any, listener: Listener): this;

  interface: BytesTestInterface;

  functions: {
    bytesToHexConvert(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<{
      0: string;
    }>;

    "bytesToHexConvert(bytes)"(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<{
      0: string;
    }>;

    read(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      new_offset: BigNumber;
      data: string;
      0: BigNumber;
      1: string;
    }>;

    "read(bytes,uint256,uint256)"(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      new_offset: BigNumber;
      data: string;
      0: BigNumber;
      1: string;
    }>;

    testUInt24(
      x: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      r: number;
      offset: BigNumber;
      0: number;
      1: BigNumber;
    }>;

    "testUInt24(uint24)"(
      x: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      r: number;
      offset: BigNumber;
      0: number;
      1: BigNumber;
    }>;
  };

  bytesToHexConvert(_in: BytesLike, overrides?: CallOverrides): Promise<string>;

  "bytesToHexConvert(bytes)"(
    _in: BytesLike,
    overrides?: CallOverrides
  ): Promise<string>;

  read(
    _data: BytesLike,
    _offset: BigNumberish,
    _len: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    new_offset: BigNumber;
    data: string;
    0: BigNumber;
    1: string;
  }>;

  "read(bytes,uint256,uint256)"(
    _data: BytesLike,
    _offset: BigNumberish,
    _len: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    new_offset: BigNumber;
    data: string;
    0: BigNumber;
    1: string;
  }>;

  testUInt24(
    x: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    r: number;
    offset: BigNumber;
    0: number;
    1: BigNumber;
  }>;

  "testUInt24(uint24)"(
    x: BigNumberish,
    overrides?: CallOverrides
  ): Promise<{
    r: number;
    offset: BigNumber;
    0: number;
    1: BigNumber;
  }>;

  callStatic: {
    bytesToHexConvert(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<string>;

    "bytesToHexConvert(bytes)"(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<string>;

    read(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      new_offset: BigNumber;
      data: string;
      0: BigNumber;
      1: string;
    }>;

    "read(bytes,uint256,uint256)"(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      new_offset: BigNumber;
      data: string;
      0: BigNumber;
      1: string;
    }>;

    testUInt24(
      x: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      r: number;
      offset: BigNumber;
      0: number;
      1: BigNumber;
    }>;

    "testUInt24(uint24)"(
      x: BigNumberish,
      overrides?: CallOverrides
    ): Promise<{
      r: number;
      offset: BigNumber;
      0: number;
      1: BigNumber;
    }>;
  };

  filters: {};

  estimateGas: {
    bytesToHexConvert(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "bytesToHexConvert(bytes)"(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    read(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    "read(bytes,uint256,uint256)"(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;

    testUInt24(x: BigNumberish, overrides?: CallOverrides): Promise<BigNumber>;

    "testUInt24(uint24)"(
      x: BigNumberish,
      overrides?: CallOverrides
    ): Promise<BigNumber>;
  };

  populateTransaction: {
    bytesToHexConvert(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "bytesToHexConvert(bytes)"(
      _in: BytesLike,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    read(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "read(bytes,uint256,uint256)"(
      _data: BytesLike,
      _offset: BigNumberish,
      _len: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    testUInt24(
      x: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;

    "testUInt24(uint24)"(
      x: BigNumberish,
      overrides?: CallOverrides
    ): Promise<PopulatedTransaction>;
  };
}