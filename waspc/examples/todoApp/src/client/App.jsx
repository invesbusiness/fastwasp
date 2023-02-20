import { Link } from "react-router-dom";

export function App({ children }) {
    return (
        <div className="p-6">
            <header className="mb-6">
                <h1 className="text-3xl font-bold">
                    <Link to="/">ToDo App</Link>
                </h1>
            </header>
            {children}
        </div>
    );
}
