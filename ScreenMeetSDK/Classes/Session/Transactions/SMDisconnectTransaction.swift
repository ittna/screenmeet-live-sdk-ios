//
//  SMReconnectTransaction.swift
//  ScreenMeet
//
//  Created by Ross on 13.01.2021.
//

import UIKit

class SMDisconnectTransaction: SMTransaction {
    
    func run() {
        transport.webSocketClient.diconnect()
        
        let mediasoupChannel = transport.channelsManager.channel(for: .mediasoup) as! SMMediasoupChannel
        mediasoupChannel.disconnect()
        
        let participantsChannel = transport.channelsManager.channel(for: .participants) as! SMParticipantsChannel
        participantsChannel.removeAllParticipants()
    }
}
