import {initialState} from "../../constants/constants.tsx";
import React, {ReactNode} from "react";
import {QRCodeGeneratorAction} from "../types/reducer-types.tsx";
import {Tabs} from "../enums/tabs-enum.tsx";
import {QRCodeRequest} from "./qr-code-request-interfaces.tsx";

export interface CoreContextType {
    state: typeof initialState;
    dispatch: React.Dispatch<QRCodeGeneratorAction>;
    activeTab: Tabs;
    setActiveTab: React.Dispatch<React.SetStateAction<Tabs>>;
    selectedCrypto: string;
    setSelectedCrypto: React.Dispatch<React.SetStateAction<string>>;
    error: string;
    setError: React.Dispatch<React.SetStateAction<string>>;
    qrBatchCount: number;
    setQrBatchCount: React.Dispatch<React.SetStateAction<number>>;
    batchData: QRCodeRequest[];
    setBatchData: React.Dispatch<React.SetStateAction<QRCodeRequest[]>>;
}

export interface CoreProviderProperties {
    children: ReactNode;
}