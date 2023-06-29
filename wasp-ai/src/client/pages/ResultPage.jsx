import { useState, useEffect, useMemo } from "react";
import getAppGenerationResult from "@wasp/queries/getAppGenerationResult";
import { useQuery } from "@wasp/queries";
import { CodeHighlight } from "../components/CodeHighlight";
import { FileTree } from "../components/FileTree";
import { createFilesAndDownloadZip } from "../zip/zipHelpers";
import { StatusPill } from "../components/StatusPill";
import { useParams } from "react-router-dom";
import { Link } from "react-router-dom";

export const ResultPage = () => {
  const { appId } = useParams();
  const [generationDone, setGenerationDone] = useState(false);
  const {
    data: appGenerationResult,
    isError,
    isLoading,
  } = useQuery(
    getAppGenerationResult,
    { appId },
    { enabled: !!appId && !generationDone, refetchInterval: 3000 }
  );
  const [activeFilePath, setActiveFilePath] = useState(null);
  const [currentStatus, setCurrentStatus] = useState({
    status: "idle",
    message: "Waiting for instructions",
  });
  const [logsVisible, setLogsVisible] = useState(false);
  const [currentFiles, setCurrentFiles] = useState({});

  useEffect(() => {
    if (
      appGenerationResult?.project?.status === "success" ||
      appGenerationResult?.project?.status === "failure"
    ) {
      setGenerationDone(true);
      setCurrentStatus({
        status:
          appGenerationResult.project.status === "success"
            ? "success"
            : "error",
        message:
          appGenerationResult.project.status === "success"
            ? "Finished"
            : "There was an error",
      });
    } else if (isError) {
      setGenerationDone(true);
    } else {
      setCurrentStatus({
        status: "inProgress",
        message: "Generating app",
      });
    }
  }, [appGenerationResult, isError]);

  const logs = appGenerationResult?.project?.logs.map((log) => log.content);

  const files = useMemo(() => {
    let files = {};
    (appGenerationResult?.project?.files ?? []).reduce((acc, file) => {
      acc[file.name] = file.content;
      return acc;
    }, files);
    return files;
  }, [appGenerationResult]);

  const freshlyUpdatedFilePaths = useMemo(() => {
    const previousFiles = currentFiles;
    setCurrentFiles(files);

    if (Object.keys(previousFiles).length === 0) {
      return [];
    }

    const updatedFilePaths = Object.entries(files).reduce(
      (updatedPaths, [path, newContent]) => {
        if (newContent === previousFiles[path]) {
          return updatedPaths;
        }
        return [...updatedPaths, path];
      },
      []
    );

    return updatedFilePaths;
  }, [files]);

  const language = useMemo(() => {
    if (activeFilePath) {
      const ext = activeFilePath.split(".").pop();
      if (["jsx", "tsx", "js", "ts", "cjs"].includes(ext)) {
        return "javascript";
      } else if (["wasp"].includes(ext)) {
        return "wasp";
      } else {
        return ext;
      }
    }
  }, [activeFilePath]);

  const interestingFilePaths = useMemo(() => {
    if (files) {
      return Object.keys(files)
        .filter(
          (path) =>
            path !== ".env.server" &&
            path !== ".env.client" &&
            path !== "src/client/vite-env.d.ts" &&
            path !== "src/client/tsconfig.json" &&
            path !== "src/server/tsconfig.json" &&
            path !== "src/shared/tsconfig.json" &&
            path !== ".gitignore" &&
            path !== "src/.waspignore" &&
            path !== ".wasproot"
        )
        .sort((a, b) => {
          if (a.endsWith(".wasp") && !b.endsWith(".wasp")) {
            return -1;
          }
          if (!a.endsWith(".wasp") && b.endsWith(".wasp")) {
            return 1;
          }
          return a.split("/").length - b.split("/").length;
        });
    } else {
      return [];
    }
  }, [files]);

  const previewLogsCount = 3;
  const visibleLogs = useMemo(() => {
    if (logs) {
      return logsVisible ? logs : logs.slice(0, previewLogsCount);
    } else {
      return [];
    }
  }, [logs, logsVisible]);

  function downloadZip() {
    const safeAppName = appGenerationResult?.project?.name.replace(
      /[^a-zA-Z0-9]/g,
      "_"
    );
    const randomSuffix = Math.random().toString(36).substring(2, 7);
    const appNameWithSuffix = `${safeAppName}-${randomSuffix}`;
    createFilesAndDownloadZip(files, appNameWithSuffix);
  }

  function toggleLogs() {
    setLogsVisible(!logsVisible);
  }

  function getEmoji(log) {
    // log.toLowerCase().includes("generated") ? "✅ " : "⌛️ "
    if (
      log.toLowerCase().includes("generated") ||
      log.toLowerCase().includes("fixed") ||
      log.toLowerCase().includes("added") ||
      log.toLowerCase().includes("updated")
    ) {
      return "✅";
    }
    if (log.toLowerCase().includes("done!")) {
      return "🎉";
    }
    if (
      log.toLowerCase().includes("error") ||
      log.toLowerCase().includes("fail")
    ) {
      return "❌";
    }
    if (log.toLowerCase().includes("warning")) {
      return "⚠️";
    }
    if (log.toLowerCase().includes("tokens usage")) {
      return "📊";
    }
    if (log.toLowerCase().endsWith("...")) {
      return "⌛️";
    }
    return "🤖";
  }

  return (
    <div className="container">
      <div className="mb-4 bg-slate-50 p-8 rounded-xl flex justify-between items-center">
        <Title />
        {appGenerationResult?.project && (
          <StatusPill status={currentStatus.status}>
            {currentStatus.message}
          </StatusPill>
        )}
      </div>

      {isError && (
        <div className="mb-4 bg-red-50 p-8 rounded-xl">
          <div className="text-red-500">
            We couldn't find the app generation result. Maybe the link is
            incorrect or the app generation has failed.
          </div>
          <Link className="button gray sm mt-4 inline-block" to="/">
            Generate a new one
          </Link>
        </div>
      )}

      {isLoading && (
        <>
          <header className="mt-4 mb-4 bg-slate-900 text-white p-8 rounded-xl flex justify-between items-flex-start">
            <div className="flex-shrink-0 mr-3">
              <Loader />
            </div>
            <pre className="flex-1">Fetching the app...</pre>
          </header>
        </>
      )}

      {logs && (
        <>
          <header className="mt-4 mb-4 bg-slate-900 text-white p-8 rounded-xl flex justify-between items-flex-start">
            <div className="flex-shrink-0 mr-3">
              {currentStatus.status === "inProgress" && <Loader />}
            </div>
            {logs && (
              <pre className="flex-1">
                {logs.length === 0 && "Waiting for logs..."}
                {visibleLogs.map((log, i) => (
                  <pre
                    key={i}
                    className="mb-2"
                    style={{
                      opacity: logsVisible
                        ? 1
                        : (previewLogsCount - i) * (1 / previewLogsCount),
                    }}
                  >
                    {getEmoji(log) + " "}
                    {log}
                  </pre>
                ))}
              </pre>
            )}
            {logs.length > 1 && (
              <div className="flex-shrink-0 ml-3">
                <button
                  onClick={toggleLogs}
                  className="p-2 px-4 rounded-full bg-slate-800 hover:bg-slate-700"
                >
                  {logsVisible ? "Collapse the logs" : "Expand the logs"}
                </button>
              </div>
            )}
          </header>
        </>
      )}

      {interestingFilePaths.length > 0 && (
        <>
          <div className="mb-2">
            <h2 className="text-xl font-bold text-gray-800">
              {appGenerationResult?.project?.name}
            </h2>
          </div>
          <div className="grid gap-4 grid-cols-[320px_1fr] mt-4">
            <aside>
              <div className="mb-2">
                <RunTheAppModal
                  onDownloadZip={downloadZip}
                  disabled={currentStatus.status !== "success"}
                />
              </div>
              {currentStatus.status !== "success" && (
                <small className="text-gray-500 text-center block my-2">
                  The app is still being generated.
                </small>
              )}
              <FileTree
                paths={interestingFilePaths}
                activeFilePath={activeFilePath}
                onActivePathSelect={setActiveFilePath}
                freshlyUpdatedPaths={freshlyUpdatedFilePaths}
              />
              <p className="text-gray-500 text-sm my-4 leading-relaxed">
                <strong>User provided prompt: </strong>
                {appGenerationResult?.project?.description}
              </p>
              {currentStatus.status === "success" && (
                <Link className="button gray w-full mt-2 block" to="/">
                  Generate another one?
                </Link>
              )}
            </aside>

            {activeFilePath && (
              <main>
                <div className="font-bold text-sm bg-slate-200 text-slate-700 p-3 rounded rounded-b-none">
                  {activeFilePath}:
                </div>
                <div
                  key={activeFilePath}
                  className="py-4 bg-slate-100 rounded rounded-t-none"
                >
                  <CodeHighlight language={language}>
                    {files[activeFilePath].trim()}
                  </CodeHighlight>
                </div>
              </main>
            )}
            {!activeFilePath && (
              <main className="p-8 bg-slate-100 rounded grid place-content-center">
                <div className="text-center">
                  <div className="font-bold">Select a file to view</div>
                  <div className="text-gray-500 text-sm">
                    (click on a file in the file tree)
                  </div>
                </div>
              </main>
            )}
          </div>
        </>
      )}
    </div>
  );
};

import React from "react";
import { Title } from "../components/Title";
import { Loader } from "../components/Loader";
import { MyDialog } from "../components/Dialog";

export default function RunTheAppModal({ disabled, onDownloadZip }) {
  const [showModal, setShowModal] = React.useState(false);
  return (
    <>
      <button
        className="button w-full"
        disabled={disabled}
        onClick={() => setShowModal(true)}
      >
        Run the app locally ⚡️
      </button>
      <MyDialog
        isOpen={showModal}
        onClose={() => setShowModal(false)}
        title="Run the app locally ⚡️"
      >
        <div className="mt-6 space-y-6">
          <WarningAboutAI />
          <p className="text-base leading-relaxed text-gray-500">
            First, you need to install Wasp locally. You can do that by running
            this command in your terminal:
          </p>
          <pre className="bg-slate-50 p-4 rounded-lg text-sm">
            curl -sSL https://get.wasp-lang.dev/installer.sh | sh
          </pre>
          <p className="text-base leading-relaxed text-gray-500">
            Then, you download the ZIP file with the generated app:
          </p>
          <button className="button w-full" onClick={onDownloadZip}>
            Download ZIP
          </button>
          <p className="text-base leading-relaxed text-gray-500">
            Unzip the file and run the app with:
          </p>
          <pre className="bg-slate-50 p-4 rounded-lg text-sm">wasp start</pre>
          <p className="text-base leading-relaxed text-gray-500">
            Congratulations, you are now running your Wasp app locally! 🎉
          </p>
        </div>
      </MyDialog>
    </>
  );
}

function WarningAboutAI() {
  return (
    <div className="bg-yellow-50 text-yellow-700 p-4 rounded">
      <div className="flex">
        <div className="ml-3">
          <p className="text-sm leading-5 font-medium">⚠️ Experimental tech</p>
          <div className="mt-2 text-sm leading-5">
            <p>
              Since this is an AI generated app, it might contain small issues.
              The bugs are usually small and easy to fix, but if you need help,
              feel free to reach out to us on{" "}
              <a
                href="https://discord.gg/rzdnErX"
                target="_blank"
                rel="noopener noreferrer"
                className="font-medium text-yellow-600 hover:text-yellow-500 transition ease-in-out duration-150"
              >
                Discord
              </a>
              .
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}