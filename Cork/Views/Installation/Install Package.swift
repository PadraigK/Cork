//
//  Add Package.swift
//  Cork
//
//  Created by David Bureš on 03.07.2022.
//

import SwiftUI

struct AddFormulaView: View
{
    @Binding var isShowingSheet: Bool

    @State private var packageRequested: String = ""

    @EnvironmentObject var brewData: BrewDataStorage
    @EnvironmentObject var appState: AppState

    @State private var isFormulaeSectionCollapsed: Bool = false
    @State private var isCasksSectionCollapsed: Bool = false

    @State private var foundPackageSelection = Set<UUID>()

    @ObservedObject var searchResultTracker = SearchResultTracker()
    @ObservedObject var installationProgressTracker = InstallationProgressTracker()

    @State var packageInstallationProcessStep: PackageInstallationProcessSteps = .ready

    @State var packageInstallTrackingNumber: Float = 0

    @FocusState var isSearchFieldFocused: Bool

    @AppStorage("showPackagesStillLeftToInstall") var showPackagesStillLeftToInstall: Bool = false
    @AppStorage("notifyAboutPackageInstallationResults") var notifyAboutPackageInstallationResults: Bool = false

    var body: some View
    {
        VStack(alignment: .leading, spacing: 10)
        {
            switch packageInstallationProcessStep
            {
            case .ready:
                SheetWithTitle(title: "add-package.title")
                {
                    InstallationInitialView(
                        searchResultTracker: searchResultTracker,
                        isShowingSheet: $isShowingSheet,
                        packageRequested: $packageRequested,
                        foundPackageSelection: $foundPackageSelection,
                        installationProgressTracker: installationProgressTracker,
                        packageInstallationProcessStep: $packageInstallationProcessStep
                    )
                }

            case .searching:
                InstallationSearchingView(
                    packageRequested: $packageRequested,
                    searchResultTracker: searchResultTracker,
                    packageInstallationProcessStep: $packageInstallationProcessStep
                )

            case .presentingSearchResults:
                VStack
                {
                    TextField("add-package.search.prompt", text: $packageRequested)
                    { _ in
                        foundPackageSelection = Set<UUID>() // Clear all selected items when the user looks for a different package
                    }
                    .focused($isSearchFieldFocused)
                    .onAppear
                    {
                        isSearchFieldFocused = true
                    }

                    List(selection: $foundPackageSelection)
                    {
                        Section
                        {
                            if !isFormulaeSectionCollapsed
                            {
                                ForEach(searchResultTracker.foundFormulae)
                                { formula in
                                    SearchResultRow(packageName: formula.name, isCask: formula.isCask)
                                }
                            }
                        } header: {
                            CollapsibleSectionHeader(headerText: "add-package.search.results.formulae", isCollapsed: $isFormulaeSectionCollapsed)
                        }
                        Section
                        {
                            if !isCasksSectionCollapsed
                            {
                                ForEach(searchResultTracker.foundCasks)
                                { cask in
                                    SearchResultRow(packageName: cask.name, isCask: cask.isCask)
                                }
                            }
                        } header: {
                            CollapsibleSectionHeader(headerText: "add-package.search.results.casks", isCollapsed: $isCasksSectionCollapsed)
                        }
                    }
                    .listStyle(.bordered(alternatesRowBackgrounds: true))
                    .frame(width: 300, height: 300)

                    HStack
                    {
                        DismissSheetButton(isShowingSheet: $isShowingSheet)

                        Spacer()

                        if isSearchFieldFocused
                        {
                            Button
                            {
                                packageInstallationProcessStep = .searching
                            } label: {
                                Text("add-package.search.action")
                            }
                            .keyboardShortcut(.defaultAction)
                        }
                        else
                        {
                            Button
                            {
                                for requestedPackage in foundPackageSelection
                                {
                                    print(getPackageFromUUID(requestedPackageUUID: requestedPackage, tracker: searchResultTracker))

                                    let packageToInstall: BrewPackage = getPackageFromUUID(requestedPackageUUID: requestedPackage, tracker: searchResultTracker)

                                    installationProgressTracker.packagesBeingInstalled.append(PackageInProgressOfBeingInstalled(package: packageToInstall, installationStage: .ready, packageInstallationProgress: 0))

                                    print("Packages to install: \(installationProgressTracker.packagesBeingInstalled)")

                                    installationProgressTracker.packageBeingCurrentlyInstalled = packageToInstall.name
                                }

                                print(installationProgressTracker.packagesBeingInstalled)

                                packageInstallationProcessStep = .installing
                            } label: {
                                Text("add-package.install.action")
                            }
                            .keyboardShortcut(.defaultAction)
                            .disabled(foundPackageSelection.isEmpty)
                        }
                    }
                }

            case .installing:
                VStack(alignment: .leading)
                {
                    ForEach(installationProgressTracker.packagesBeingInstalled)
                    { packageBeingInstalled in

                        if packageBeingInstalled.installationStage != .finished
                        {
                            ProgressView(value: installationProgressTracker.packagesBeingInstalled[0].packageInstallationProgress, total: 10)
                            {
                                switch packageBeingInstalled.installationStage
                                {
                                case .ready:
                                    Text("add-package.install.ready")

                                // FORMULAE
                                case .loadingDependencies:
                                    Text("add-package.install.loading-dependencies")

                                case .fetchingDependencies:
                                    Text("add-package.install.fetching-dependencies")

                                case .installingDependencies:
                                    Text("add-package.install.installing-dependencies-\(installationProgressTracker.numberInLineOfPackageCurrentlyBeingInstalled)-of-\(installationProgressTracker.numberOfPackageDependencies)")

                                case .installingPackage:
                                    Text("add-package.install.installing-package")

                                case .finished:
                                    Text("add-package.install.finished")

                                // CASKS
                                case .downloadingCask:
                                    Text("add-package.install.downloading-cask-\(installationProgressTracker.packagesBeingInstalled[0].package.name)")

                                case .installingCask:
                                    Text("add-package.install.installing-cask-\(installationProgressTracker.packagesBeingInstalled[0].package.name)")

                                case .linkingCaskBinary:
                                    Text("add-package.install.linking-cask-binary")

                                case .movingCask:
                                    Text("add-package.install.moving-cask-\(installationProgressTracker.packagesBeingInstalled[0].package.name)")
                                }
                            }
                        }
                        else
                        { // Show this when the installation is finished
                            Text("add-package.install.finished")
                                .onAppear
                                {
                                    packageInstallationProcessStep = .finished
                                }
                        }
                    }
                }
                .onAppear
                {
                    for var packageToInstall in installationProgressTracker.packagesBeingInstalled
                    {
                        Task(priority: .userInitiated)
                        {
                            let installationResult = try! await installPackage(installationProgressTracker: installationProgressTracker, brewData: brewData)
                            print("Installation result: \(installationResult)")
                        }
                    }
                }

            case .finished:
                DisappearableSheet(isShowingSheet: $isShowingSheet)
                {
                    ComplexWithIcon(systemName: "checkmark.seal")
                    {
                        HeadlineWithSubheadline(
                            headline: "add-package.finished",
                            subheadline: "add-package.finished.description",
                            alignment: .leading
                        )
                    }
                }
                .onAppear
                {
                    appState.cachedDownloadsFolderSize = directorySize(url: AppConstants.brewCachedDownloadsPath)

                    if notifyAboutPackageInstallationResults
                    {
                        sendNotification(title: String(localized: "notification.install-finished"))
                    }
                }

            default:
                VStack(alignment: .leading)
                {
                    ComplexWithIcon(systemName: "wifi.exclamationmark")
                    {
                        HeadlineWithSubheadline(
                            headline: "add-package.network-error",
                            subheadline: "add-package.network-error.description",
                            alignment: .leading
                        )
                    }

                    HStack
                    {
                        Spacer()

                        DismissSheetButton(isShowingSheet: $isShowingSheet)
                    }
                }
            }
        }
        .padding()
    }
}
