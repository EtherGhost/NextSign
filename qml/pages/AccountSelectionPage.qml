import QtQuick 2.7
import "qrc:/NextCommon" as NextCommon

NextCommon.AccountPage {
    id: page

    property var appController

    appName: appController.appName
    logPrefix: "NextSign"
    appApplicationId: "nextsign.cloudsite_nextsign"
    nextcloudServiceId: "nextsign.cloudsite_nextsign_nextcloud"
    owncloudServiceId: "nextsign.cloudsite_nextsign_owncloud"

    onAccountAuthorized: function(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl) {
        if (page.appController && page.appController.accountChanged) {
            page.appController.accountChanged(accountId, displayName, providerId, serviceId, serverUrl, avatarUrl)
        }
    }
}
