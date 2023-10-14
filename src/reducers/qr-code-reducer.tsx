import {QRCodeGeneratorState} from "../ts/interfaces/qr-code-generator-state.tsx";
import {QRCodeGeneratorAction} from "../ts/types/reducer-types.tsx";
import {initialState} from "../constants/constants.tsx";

export const qrCodeReducer = (state: QRCodeGeneratorState, action: QRCodeGeneratorAction): QRCodeGeneratorState => {
    switch (action.type) {
        case 'SET_FIELD': {
            return {...state, [action.field]: action.value};
        }
        case 'SET_LOADING': {
            return {...state, isLoading: action.value};
        }
        case 'SET_QRCODE_URL': {
            return {...state, qrCodeURL: action.value, isLoading: false};
        }
        case 'RESET_STATE': {
            return {...initialState};
        }
        default: {
            return state;
        }
    }
};
